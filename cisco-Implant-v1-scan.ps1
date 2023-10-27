
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

$RunTime = Get-Date -Format "dd-MM-yyyy"
$logFile = "$PSScriptRoot\CiscoImplantV1Log-$RunTime.txt"
Remove-Item $logFile -Force -ErrorAction SilentlyContinue

"Number,Result,ip,hash"|Tee-Object -FilePath $logFile -Append


function Open-File([string] $initialDirectory){

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.title = "Please choose the .txt file"
    $OpenFileDialog.filter = "All files (*.txt)| *.txt"
    $OpenFileDialog.ShowDialog() |  Out-Null

    return $OpenFileDialog.filename
} 


$Help = @"

Cisco IOS XE Vulnerability (check for hash implant)
----------------------------------------------------
CVE-2023-20198 (CVSS score: 10.0) and CVE-2023-20273 (CVSS score: 7.2)
https://github.com/fox-it/cisco-ios-xe-implant-detection
https://blog.talosintelligence.com/active-exploitation-of-cisco-ios-xe-software/

1.Please prepare the CISCO devices ip list file (each ip in a different line)
2.The script will check if the device has been compromized and is implanted
3.The result will be provided in the file [$logFile]

curl -k -H "Authorization: 0ff4fbf0ecffa77ce8d3852a29263e263838e9bb" -X POST "https://DEVICEIP/webui/logoutconfirm.html?logon_hash=1"

Note:
In order to download the file please run this command from powershell 
Start-BitsTransfer -Source https://raw.githubusercontent.com/contigon/Tools/master/cisco-Implant-vs-scan.ps1

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
    
    $headers = @{
        "Authorization" = "0ff4fbf0ecffa77ce8d3852a29263e263838e9bb"
    }

    $response = Invoke-WebRequest -Method Post -Headers $headers -Uri "https://$line/webui/logoutconfirm.html?logon_hash=1" -TimeoutSec 3

    $IMPLANT = ($response.Content).Trim()
    $IsHex = $response.Content.Length
        
    if ($isHex -eq 19) {
        "$x,Implanted,$line" | Tee-Object -FilePath $logFile -Append
    } else {
        "$x,Not Implanted,$line" | Tee-Object -FilePath $logFile -Append
    }
} catch {
    $TimeoutStatus = $_.Exception.status
    if($TimeoutStatus -eq "Timeout"){
        "$x,Timeout,$line" |Tee-Object -FilePath $logFile -Append
    } else {

    $StatusCode = $_.Exception.Response.StatusCode
    
    if ($StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
        "$x,User was not found,$line" |Tee-Object -FilePath $logFile -Append
    } elseif ($StatusCode -eq [System.Net.HttpStatusCode]::InternalServerError) {
        "$x,InternalServerError,$line" |Tee-Object -FilePath $logFile  -Append
    } elseif ($StatusCode -eq [System.Net.HttpStatusCode]::InternalServerError) {
        "$x,InternalServerError,$line" |Tee-Object -FilePath $logFile -Append
    }
    else {
        "$x,503 Service Unavailable,$line"|Tee-Object -FilePath $logFile -Append
    }
  }
  }
 } 
 

$data = Import-Csv $logFile

$Implanted = $data | where-Object Result -EQ "Implanted"
$Unavailable = $data | where-Object Result -EQ "503 Service Unavailable"
$OK = $data | where-Object Result -EQ "200-OK"
$InternalServerError = $data | where-Object Result -EQ "InternalServerError"
$TOut = $data | where-Object Result -EQ "Timeout"

Write-Host " -----------------------------REPORT---------------------------------"
Write-Host "Implanted:" $Implanted.Count -ForegroundColor Red
Write-Host "200 OK =" $OK.Count -ForegroundColor Red
Write-Host "503 Service Unavailable:" $Unavailable.Count -ForegroundColor Green
Write-Host "Internal Server Error:" $InternalServerError.Count -ForegroundColor Green
Write-Host "Timeout:" $TOut.Count -ForegroundColor Green
Write-Host "TOTAL DEVICES:" $data.Count -ForegroundColor Yellow
Write-Host " -------------------------------------------------------------------"

explorer $logFile
