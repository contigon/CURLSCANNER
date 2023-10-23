Clear-Host

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
Execute TELNET command with list of IP,PORTS from .xlsx file
test if host is responding!!
----------------------------------------------------------------
Table: IP | PORT
Note: Sheet name should be "HOSTS"

"@

Write-Host $Help -ForegroundColor Yellow
$input =  Read-Host "Press Enter to continue or (q) to quit"
if ($input -eq "q") {
    break
}

$RunTime = Get-Date -Format "dd-MM-yyyy"
$ScanResultsCSV = "$PSScriptRoot\ScanResultsCSV-$RunTime.csv"
$ScanResultsReport = "$PSScriptRoot\ScanResultsReport-$RunTime.txt"
Remove-Item $ScanResultsCSV -Force -ErrorAction SilentlyContinue
Remove-Item $ScanResultsReport -Force -ErrorAction SilentlyContinue

function Open-File([string] $initialDirectory){

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.title = "Please choose the .xlsx file"
    $OpenFileDialog.filter = "All files (*.xlsx)| *.xlsx"
    $OpenFileDialog.ShowDialog() |  Out-Null

    return $OpenFileDialog.filename
} 


Write-Host "Please choose the .xlsx file:"
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

$Sheet = Import-Excel -Path $OpenFile -WorksheetName "HOSTS"

# Display the data by using the column names:
$ip = $Sheet | Select 'ip'
$port = $Sheet | Select 'port'
#$TotalIPs = $ip.Count
$TotalIPs = 50


$data = @()

for($x=0;$x -le $TotalIPs;$x++)
#for($x=0;$x -lt 20;$x++)
{
    
    $HostIP = $ip[$x].IP
    $HostPORT = $port[$x].port
    $TelnetTest = Test-Port $HostIP $HostPORT
    $Stat = $TelnetTest.PortOpened
    $data += ($TelnetTest)
    Write-Progress -Activity "Scanning IP=$HostIP PORT=$HostPORT ALIVE=$Stat" -Status "$x of $TotalIPs" -PercentComplete ($x/$TotalIPs*100)
}

$data | Format-Table -Property RemoteHostname,RemotePort,PortOpened | Tee-Object -FilePath $ScanResultsReport
$data | Export-Csv -Path $ScanResultsCSV -NoTypeInformation

#$write-Host "Found $AliveHosts Live Hosts from $TotalIPs ip addresses" -ForegroundColor Yellow
explorer $ScanResultsCSV
explorer $ScanResultsReport