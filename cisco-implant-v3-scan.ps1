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
$logFile = "$PSScriptRoot\CiscoImplantV2Log-$RunTime.txt"
Remove-Item $logFile -Force -ErrorAction SilentlyContinue
"Number,Result,ip"|Tee-Object -FilePath $logFile -Append


$Help = @"

 Cisco IOS XE Vulnerability (Implant V3)
----------------------------------------------
CVE-2023-20198 (CVSS score: 10.0) and CVE-2023-20273 (CVSS score: 7.2)
https://github.com/fox-it/cisco-ios-xe-implant-detection
https://blog.talosintelligence.com/active-exploitation-of-cisco-ios-xe-software/

1.Please prepare the CISCO devices ip list file (each ip in a different line)
2.The script will check if the device has been compromized and is implanted
3.The result will be provided in the file [$logFile]

CISCO IOS XE is implanted if:
    1. URL https://DEVICEIP/%25 returns "404 Not Found”
    2. standard login page (webui) is presented with 200 OK HTTP response is not containing a JavaScript redirect


Note:
In order to download the file please run this command from powershell 
Start-BitsTransfer -Source https://raw.githubusercontent.com/contigon/Tools/master/cisco-Implant-v3-scan.ps1

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

        #not used for that check!!
        $headers = @{
        "Authorization" = "0ff4fbf0ecffa77ce8d3852a29263e263838e9bb"
        }

        #Get HTTP/HTTPS response
        $responseHTTP = Invoke-WebRequest "http://$line/%25" -TimeoutSec 5
        $CheckRedirectHTTP = ($responseHTTP.tostring() -split "[`r`n]"  | select-string "/webui/login/redirect.js").ToString().trim()        
        #Write-Host $responseHTTP.StatusCode -ForegroundColor Yellow
        #Write-Host $responseHTTP -ForegroundColor Yellow
        #Write-Host ($CheckRedirectHTTP).ToString().trim() -ForegroundColor Yellow

        $responseHTTPS = Invoke-WebRequest "https://$line/%25" -TimeoutSec 5
        $CheckRedirectHTTPS = (($responseHTTPS.tostring() -split "[`r`n]"  | select-string "/webui/login/redirect.js")).ToString().trim()
        #Write-Host $responseHTTPS.StatusCode -ForegroundColor Green
        #Write-Host $responseHTTPS -ForegroundColor Green
        #Write-Host $CheckRedirectHTTPS -ForegroundColor Green
       
       #check for Implant v3
        if (($CheckRedirectHTTP -eq '<script src="/webui/login/redirect.js"></script>') -or ($CheckRedirectHTTPS -eq '<script src="/webui/login/redirect.js"></script>'))
        {
        
            
            "$x,Not Implanted,$line" | Tee-Object -FilePath $logFile -Append 
            
        } else {

            "$x,Implanted v3,$line" | Tee-Object -FilePath $logFile -Append 

        }

} catch {
    $TimeoutStatus = $_.Exception.status
    if($TimeoutStatus -eq "Timeout"){
        "$x,Timeout,$line" |Tee-Object -FilePath $logFile -Append
    } else {

    #status code 404 not found means there can be implant v1 or v2
    $StatusCode = $_.Exception.Response.StatusCode 
    if ($StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
        "$x,Implanted v2,$line" |Tee-Object -FilePath $logFile -Append
    } elseif ($StatusCode -eq [System.Net.HttpStatusCode]::InternalServerError) {
        "$x,InternalServerError,$line" |Tee-Object -FilePath $logFile  -Append
    } 
    else {
        "$x,503 Service Unavailable,$line"|Tee-Object -FilePath $logFile -Append
    }
  }
  }
 } 

$data = Import-Csv $logFile

$Implantedv2 = $data | where-Object Result -EQ "Implanted v2"
$Implantedv3 = $data | where-Object Result -EQ "Implanted v3"
$NotImplanted = $data | where-Object Result -EQ "Not Implanted"
$Unavailable = $data | where-Object Result -EQ "503 Service Unavailable"
$OK = $data | where-Object Result -EQ "200-OK"
$InternalServerError = $data | where-Object Result -EQ "InternalServerError"
$TOut = $data | where-Object Result -EQ "Timeout"

Write-Host " --------------------REPORT CISCO IMPLANT V2------------------------"
Write-Host "Implanted v2:" $Implantedv2.Count -ForegroundColor Red
Write-Host "Implanted v3:" $Implantedv3.Count -ForegroundColor Red
Write-Host "Not Implanted:" $NotImplanted.Count -ForegroundColor Green
Write-Host "503 Service Unavailable:" $Unavailable.Count -ForegroundColor Gray
Write-Host "Internal Server Error:" $InternalServerError.Count -ForegroundColor DarkYellow
Write-Host "Timeout:" $TOut.Count -ForegroundColor White
Write-Host "Total Devices:" $data.Count -ForegroundColor Yellow
Write-Host " -------------------------------------------------------------------"

explorer $logFile