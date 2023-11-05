cls

#install excel module to work with excel files
#Install-Module -Name ImportExcel -Scope CurrentUser -Force

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


function Open-File([string] $initialDirectory){

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.title = "Please choose the .txt file"
    $OpenFileDialog.filter = "All files (*.txt)| *.txt"
    $OpenFileDialog.ShowDialog() |  Out-Null

    return $OpenFileDialog.filename
} 


$RunTime = Get-Date -Format "dd-MM-yyyy"
$logFile = "$PSScriptRoot\ResultLog-$RunTime.txt"
Remove-Item $logFile -Force -ErrorAction SilentlyContinue
"Number,Result,client version,ip"|Tee-Object -FilePath $logFile -Append


$Help = @"

CVE-2023-4966: Exploitation of Citrix NetScaler Information Disclosure Vulnerability
-------------------------------------------------------------------------------------
https://www.rapid7.com/blog/post/2023/10/25/etr-cve-2023-4966-exploitation-of-citrix-netscaler-information-disclosure-vulnerability/


1.Please prepare the  devices [ip:port] list file (each ip in a different line)
2.The script will check if the device has been compromized 
3.The result will be provided in the file [$logFile]

curl -k https://<IP>/vpn/pluginlist.xml | grep version

PATCHED Version:
version="23.8.1.5" path="/epa/scripts/win/nsepa_setup.exe"

Note:
In order to download the file please run this command from powershell 
Start-BitsTransfer -Source https://raw.githubusercontent.com/contigon/Tools/master/CITRIX-CheckClientVersion-v1-scan.ps1

"@

Write-Host $Help -ForegroundColor Yellow
$input =  Read-Host "Press Enter to continue or (q) to quit"
if ($input -eq "q") {
    break
}

Write-Host "Please choose the <ip>.txt file:"
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

$ip = Get-Content -Path $OpenFile

$x = 0
foreach($line in $ip)
{
$x = ++$X
 
try {
    
    $response = Invoke-WebRequest "https://$line/vpn/pluginlist.xml" -TimeoutSec 3

    if ($response.StatusCode -eq 200) {
        
        $xml = [xml]$response.content
        $version = $xml.SelectSingleNode('//repositories/repository/plugin').version

        
        if($version -eq "23.8.1.5"){
           
            "$x,TRUE,$version,$line" | Tee-Object -FilePath $logFile -Append


        } else {
            
             "$x,FALSE,$version,$line" | Tee-Object -FilePath $logFile -Append

        }
    } 
} catch {
    $TimeoutStatus = $_.Exception.status
    if($TimeoutStatus -eq "Timeout"){
        "$x,Timeout,,$line" |Tee-Object -FilePath $logFile -Append
    } else {

    $StatusCode = $_.Exception.Response.StatusCode 
    if ($StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
        "$x,Not-Found,,$line" |Tee-Object -FilePath $logFile -Append
    } elseif ($StatusCode -eq [System.Net.HttpStatusCode]::InternalServerError) {
        "$x,InternalServerError,,$line" |Tee-Object -FilePath $logFile  -Append
    } 
    else {
        "$x,503-Service-Unavailable,,$line"|Tee-Object -FilePath $logFile -Append
    }
  }
  }
 } 

$data = Import-Csv $logFile

$ClientVersionOK = $data | where-Object Result -EQ "TRUE"
$ClientVersionDifferent = $data | where-Object Result -EQ "FALSE"
$Unavailable = $data | where-Object Result -EQ "503-Service-Unavailable"
$OK = $data | where-Object Result -EQ "200-OK"
$InternalServerError = $data | where-Object Result -EQ "InternalServerError"
$TOut = $data | where-Object Result -EQ "Timeout"
$NotFound = $data | where-Object Result -EQ "Not-Found"

Write-Host " ---------------CITRIX CLIENT VERSION 23.8.1.5---------------"
Write-Host "CLIENT VERSION OK:" $ClientVersionOK.Count -ForegroundColor Green
Write-Host "CLIENT VERSION Different:" $ClientVersionDifferent.Count -ForegroundColor Red
Write-Host "200 OK =" $OK.Count -ForegroundColor Red
Write-Host "503 Service Unavailable:" $Unavailable.Count -ForegroundColor Green
Write-Host "Not Found:" $NotFound.Count -ForegroundColor Green
Write-Host "Internal Server Error:" $InternalServerError.Count -ForegroundColor Green
Write-Host "Timeout:" $TOut.Count -ForegroundColor Green
Write-Host "TOTAL DEVICES:" $data.Count -ForegroundColor Yellow
Write-Host " -------------------------------------------------------------------"

explorer $logFile