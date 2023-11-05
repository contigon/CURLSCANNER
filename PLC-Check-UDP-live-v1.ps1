Clear-Host

$RunTime = Get-Date -Format "dd-MM-yyyy"
$UDPResultsCSV = "$PSScriptRoot\UDPResultsCSV-$RunTime.csv"
$UDPResultslog = "$PSScriptRoot\UDPResultslog-$RunTime.txt"
Remove-Item $UDPResultsCSV -Force -ErrorAction SilentlyContinue
Remove-Item $UDPResultslog -Force -ErrorAction SilentlyContinue

$Help = @"

----------------------------------------------------------------
Check if PLC device is Alive [UDP]
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
$TotalTCP=0;$CsvIPFile | foreach ($_){if($_.transport -eq "TCP"){$TotalTCP+=1}}
$TotalUDP =  $TotalIPs - $TotalTCP
Write-Host "Total IP's = $TotalIPs | TCP[$TotalTCP] UDP[$TotalUDP]"

#TEST IF [UDP] PORTS ARE OPEN
$data = @()
for($x=0;$x -le $TotalUDP;$x++)
#for($x=0;$x -le 15;$x++)
{  
    $HostIp = $CsvIPFile[$x].ip
    $HostPort = $CsvIPFile[$x].port
    $HostTransport = $CsvIPFile[$x].transport

    #PORT 161
    #if(($HostTransport -eq "UDP") -and ($hostport -eq "161")){
    if(($HostTransport -eq "UDP")){
        
        #$cmd = "nmap.exe -sUV  $hostip -pU:$hostport -noninteractive -host-timeout 30s"
        $cmd = "nmap.exe -Pn  -sU $hostip -pU:$hostport -noninteractive -reason -min-rate 10000"
        
        $a = Invoke-Expression $cmd         
        for($i=0;$i -lt $a.Length;$i++){
            if($a[$i].Contains("open")){$data+="$x $HostIp " + $a[$i];$stat = "$x $HostIp " + $a[$i];$stat}
            if($a[$i].Contains("down")){$data+="$x $HostIp  Host seems down";$stat = "$x $HostIp  Host seems down";$stat}
        }
        Write-Progress -Activity "Scanning IP=$HostIp PORT=$HostPort PROTOCOL=$HostTransport ALIVE=$Stat" -Status "$x of $TotalUDP" -PercentComplete ($x/$TotalUDP*100)
    }
}

$data | Format-Table -Property RemoteHostname,RemotePort,PortOpened | Tee-Object -FilePath $UDPResultslog
$data | Export-Csv -Path $UDPResultsCSV -NoTypeInformation