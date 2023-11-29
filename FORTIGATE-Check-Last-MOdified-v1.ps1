
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
$logFile = "$PSScriptRoot\FGT-Last-MOdified-Log-$RunTime.txt"
Remove-Item $logFile -Force -ErrorAction SilentlyContinue

"Number,Result,Last-Modified,ip"|Tee-Object -FilePath $logFile -Append


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

Get FORTIGATE Last-Modified Header
----------------------------------
# Can validate RECENTLY PATCHED FORTIOS DEVICES (CVE-2023-27997)

1.Please prepare the devices [ip:port] list file (each ip in a different line)
2.The script will get the device Last-Modified Header
3.The result will be provided in the file [$logFile]

example of ip.txt file:
112.133.225.2:10433
221.139.225.34:4433


Note:
In order to download the file please run this command from powershell 
Start-BitsTransfer -Source https://raw.githubusercontent.com/contigon/Tools/master/FORTIGATE-Check-Last-Modified.ps1

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

    $response = Invoke-WebRequest -Uri "https://$line"
    $LastModified = $response.Headers
    $LastModified = $LastModified.'Last-Modified'
    $LastModified = Get-Date $LastModified -Format "dd-MM-yyyy"
    "$x,Last Modified,$LastModified,$line" | Tee-Object -FilePath $logFile -Appen


} catch {
    $TimeoutStatus = $_.Exception.status
    if($TimeoutStatus -eq "Timeout"){
        "$x,Timeout,,$line" |Tee-Object -FilePath $logFile -Append
    } else {

    $StatusCode = $_.Exception.Response.StatusCode
    
    if ($StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
        "$x,User was not found,,$line" |Tee-Object -FilePath $logFile -Append
    } elseif ($StatusCode -eq [System.Net.HttpStatusCode]::InternalServerError) {
        "$x,InternalServerError,,$line" |Tee-Object -FilePath $logFile  -Append
    } elseif ($StatusCode -eq [System.Net.HttpStatusCode]::InternalServerError) {
        "$x,InternalServerError,,$line" |Tee-Object -FilePath $logFile -Append
    }
    else {
        "$x,503 Service Unavailable,,$line"|Tee-Object -FilePath $logFile -Append
    }
  }
  }
 } 
 

$data = Import-Csv $logFile
$data

explorer $logFile
