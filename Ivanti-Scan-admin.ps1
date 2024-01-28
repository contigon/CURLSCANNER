cls


#input file is ip list (each in seperate line)
#tchecking https://<$ip>/api/v1/cav/client/status/../../admin/options 
 
# bypassing SSL/TLS check

if ("TrustAllCertsPolicy" -as [type]) {} else {
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
}

function Open-File([string] $initialDirectory){

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.title = "Please choose the .txt file"
    $OpenFileDialog.filter = "All files (*.txt)| *.txt"
    $OpenFileDialog.ShowDialog() |  Out-Null

    return $OpenFileDialog.filename
} 

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

$ipFile = Get-Content -Path $OpenFile

$RunTime = Get-Date -Format "dd-MM-yyyy"
$logFile = "$PSScriptRoot\IvantiLog1-$RunTime.txt"
Remove-Item $logFile -Force -ErrorAction SilentlyContinue
"Number,Result,ip" | Tee-Object -FilePath $logFile -Append

$x = 0

foreach($ip in $ipFile){

$x = ++$X

    try {
        
        $response = Invoke-WebRequest -UseBasicParsing -Uri "https://$ip/api/v1/cav/client/status/../../admin/options" -TimeoutSec 15
        $resStatus = $response.StatusDescription

        if ($resStatus -eq "OK") {

            "$x,$resStatus,https://$ip/api/v1/cav/client/status/../../admin/options" | Tee-Object -FilePath $logFile -Append  
        } 

    } catch {
    
        $StatusCode = $_.Exception.status
        "$x,$StatusCode,https://$ip/api/v1/cav/client/status/../../admin/options" | Tee-Object -FilePath $logFile -Append
    }


}