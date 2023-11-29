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
$logFile = "$PSScriptRoot\CiscoImplantV4Log-$RunTime.txt"
Remove-Item $logFile -Force -ErrorAction SilentlyContinue
Remove-Item $PSScriptRoot\CiscoImplantV4Log-Requests.txt -Force -ErrorAction SilentlyContinue
#"Number,Result,ip"|Tee-Object -FilePath $logFile -Append


$Help = @"

 Cisco IOS XE Vulnerability (Implant V4)
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

Sample ip.txt file:
62.90.118.227
62.90.118.191
132.74.189.249


Note:
In order to download the file please run this command from powershell 
Start-BitsTransfer -Source https://raw.githubusercontent.com/contigon/Tools/master/cisco-Implant-v4-scan.ps1

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
            
            Write-Host "https://$line/%25" -ForegroundColor Yellow
            Write-Host "https://$line/%66eatures/iox/lm/static/localmgmt/sysinfo.html" -ForegroundColor Yellow
            $reqHTTPS = Invoke-WebRequest -uri ("https://$line/%66eatures/iox/lm/static/localmgmt/sysinfo.html") -TimeoutSec 5          
            $sysinfoHTTPS = ($responseHTTPS.ParsedHtml.IHTMLDocument2_body.IHTMLElement_innerText).Contains("ProcessesTotal")  
            "$x," + $line + ",443," + $sysinfoHTTPS + "," | tee -FilePath $logFile -Append
    

        } catch {

            "$x," + $line + ",443," + $_.Exception.status + "," + $_.Exception.Response.StatusCode | tee -FilePath  $logFile -Append

        }

        
        try {

            $reqHTTP = Invoke-WebRequest -uri ("http://$line/%66eatures/iox/lm/static/localmgmt/sysinfo.html") -TimeoutSec 5          
            $sysinfoHTTP = ($responseHTTP.ParsedHtml.IHTMLDocument2_body.IHTMLElement_innerText).Contains("ProcessesTotal")
             "$x," + $line + ",80," + $sysinfoHTTP + "," | tee -FilePath  $logFile -Append
            "https://$line/%66eatures/iox/lm/static/localmgmt/sysinfo.html" | tee -FilePath - $logFile -Append 

        } catch {

             "$x," + $line + ",80," + $_.Exception.status + "," + $_.Exception.Response.StatusCode | tee -FilePath  $logFile -Append


        }

}     