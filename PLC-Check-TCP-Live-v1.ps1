Clear-Host
#Install-Module -Name ImportExcel -Scope CurrentUser -Force

function Test-Port {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, HelpMessage = 'Could be suffixed by :Port')]
        [String[]]$ComputerName,

        [Parameter(HelpMessage = 'Will be ignored if the port is given in the param ComputerName')]
        [Int]$Port = 5985,

        [Parameter(HelpMessage = 'Timeout in millisecond. Increase the value if you want to test Internet resources.')]
        [Int]$Timeout = 1000
    )

    begin {
        $result = [System.Collections.ArrayList]::new()
    }

    process {
        foreach ($originalComputerName in $ComputerName) {
            $remoteInfo = $originalComputerName.Split(":")
            if ($remoteInfo.count -eq 1) {
                # In case $ComputerName in the form of 'host'
                $remoteHostname = $originalComputerName
                $remotePort = $Port
            } elseif ($remoteInfo.count -eq 2) {
                # In case $ComputerName in the form of 'host:port',
                # we often get host and port to check in this form.
                $remoteHostname = $remoteInfo[0]
                $remotePort = $remoteInfo[1]
            } else {
                $msg = "Got unknown format for the parameter ComputerName: " `
                    + "[$originalComputerName]. " `
                    + "The allowed formats is [hostname] or [hostname:port]."
                Write-Error $msg
                return
            }

            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $portOpened = $tcpClient.ConnectAsync($remoteHostname, $remotePort).Wait($Timeout)

            $null = $result.Add([PSCustomObject]@{
                RemoteHostname       = $remoteHostname
                RemotePort           = $remotePort
                PortOpened           = $portOpened
                TimeoutInMillisecond = $Timeout
                SourceHostname       = $env:COMPUTERNAME
                OriginalComputerName = $originalComputerName
                })
        }
    }

    end {
        return $result
    }
}

# bypassing SSL/TLS check
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

$Help = @"

----------------------------------------------------------------
Check if PLC device is Alive
From IP/PORTS/PROTOCOLCSV file !!
----------------------------------------------------------------
Table: IP | PORT | PROTOCOL (TCP/UDP)
Note: Sheet name should be "HOSTS"

"@

Write-Host $Help -ForegroundColor Yellow
#$input =  Read-Host "Press Enter to continue or (q) to quit"
$input = "N"
if ($input -eq "q") {
    break
}

$RunTime = Get-Date -Format "dd-MM-yyyy"
$ResultsCSV = "$PSScriptRoot\TCPResultsCSV-$RunTime.csv"
$ResultsReport = "$PSScriptRoot\TCPResultsLog-$RunTime.txt"
Remove-Item $ResultsCSV -Force -ErrorAction SilentlyContinue
Remove-Item $ResultsReport -Force -ErrorAction SilentlyContinue

function Open-File([string] $initialDirectory){

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.title = "Please choose the .csv file"
    $OpenFileDialog.filter = "All files (*.csv)| *.csv"
    $OpenFileDialog.ShowDialog() |  Out-Null

    return $OpenFileDialog.filename
} 


Write-Host "Please choose the .csv file:"
$OpenFile=Open-File $env:USERPROFILE 

if ($OpenFile -ne "") 
{
    echo "FileName: $OpenFile" 
} 
else 
{
    echo "No File was chosen"
    exit
}

#CSV format (IP_str,port,transport)
$CsvIPFile = Import-Csv $OpenFile
$TotalIPs = $CsvIPFile.count
$TotalTCP=0;
$CsvIPFile | foreach ($_){if($_.transport -eq "tcp"){$TotalTCP+=1}}
$TotalUDP =  $TotalIPs - $TotalTCP
Write-Host "Total IP's = $TotalIPs | TCP[$TotalTCP] UDP[$TotalUDP]"
#$TotalIPs = 50


#TEST IF [TCP] PORTS ARE OPEN
$data = @()
for($x=0;$x -le $TotalIPs;$x++)
{  
    $HostIp = $CsvIPFile[$x].IP_str
    $HostPort = $CsvIPFile[$x].port
    $HostTransport = $CsvIPFile[$x].transport

    if($HostTransport -eq "TCP"){
    $TelnetTest = Test-Port $HostIP $HostPort
    $Stat = $TelnetTest.PortOpened
    $data += $TelnetTest

    Write-Progress -Activity "Scanning IP=$HostIp PORT=$HostPort PROTOCOL=$HostTransport ALIVE=$Stat" -Status "$x of $TotalTCP" -PercentComplete ($x/$TotalTCP*100)
    }
}

$data | Format-Table -Property RemoteHostname,RemotePort,PortOpened | Tee-Object -FilePath $ResultsReport
$data | Export-Csv -Path $ResultsCSV -NoTypeInformation

#$write-Host "Found $AliveHosts Live Hosts from $TotalIPs ip addresses" -ForegroundColor Yellow
explorer $ResultsCSV
explorer $ResultsReport