Clear-Host
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

Execute Curl command with list of IP,PORTS from .xlsx file
------------------------------------------------------

1.Execute query in shodan

Cisco IOS XE Zero-Day Vulnerability (CVE-2023-20198): http.html_hash:1076109428 country:il

2.Download the shodan results JSON file

3.Convert the shodan file to xlsx using the shodan convert command

4.The .xlsx file should have the IP address in the 1st column and PORT in the 2ns colums

"@
Write-Host $Help -ForegroundColor Yellow

$RunTime = Get-Date -Format "dd-MM-yyyy"
$logFile = "$PSScriptRoot\log-$RunTime.txt"
Remove-Item $logFile -Force -ErrorAction SilentlyContinue

# First-time setup, install the module:
Install-Module ImportExcel -Scope CurrentUser

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
$OpenFile=Open-File "C:\Users\omer\Desktop\VDP\CISCO" #$env:USERPROFILE 

if ($OpenFile -ne "") 
{
    echo "FileName: $OpenFile" 
} 
else 
{
    echo "No File was chosen"
    exit
}

$Sheet = Import-Excel -Path $OpenFile -WorksheetName "Raw Data"
#$Sheet = Import-Excel -Path $FileBrowse -WorksheetName "Raw Data"

# Display the data by using the column names:
$ip = $Sheet | Select 'ip'
$port = $Sheet | Select 'port'
$TotalIPs = $ip.Count

Write-Host "scanning $TotalIPs ip addresses..." -ForegroundColor Yellow

for($x=0;$x -lt $TotalIPs;$x++)
{
$CiscoIP = $ip[$x].IP
$CiscoPORT = $port[$x].port

try {
    
    if($CiscoPORT -ceq 80){
        $URL = "http://$CiscoIP/webui/logoutconfirm.html?logon_hash=1"
        $response = Invoke-WebRequest -Method Post -Uri $URL 
        } elseif($CiscoPORT -ceq 443 ){
        $URL = "https://$CiscoIP/webui/logoutconfirm.html?logon_hash=1"
        $response = Invoke-WebRequest -Method Post -Uri $URL
         }
          else{
        $URL = "http://${CiscoIP}:${CiscoPORT}/webui/logoutconfirm.html?logon_hash=1"
        $response = Invoke-WebRequest -Method Post -Uri $URL
    }
        
   
    $isHex = $response.Content
    if ($isHex.length -lt 20) {
        $host.UI.RawUI.ForegroundColor = "Red"
        "$x,Implanted,$CiscoIP,$CiscoPortL,$isHex,$URL" | Tee-Object -FilePath $logFile -Append 
        $host.UI.RawUI.ForegroundColor = "White"
                
    } else {
        $host.UI.RawUI.ForegroundColor = "Green"
        "$x,Not Implanted,$CiscoIP,$CiscoPort,$URL" | Tee-Object -FilePath $logFile -Append
         $host.UI.RawUI.ForegroundColor = "White"
    }
} catch {
    $StatusCode = $_.Exception.Response.StatusCode
    if ($StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
        "$x,User was not found,$CiscoIP,$CiscoPort,$URL" |Tee-Object -FilePath $logFile -Append
    } elseif ($StatusCode -eq [System.Net.HttpStatusCode]::InternalServerError) {
        "$x,InternalServerError,$CiscoIP,$CiscoPort,$URL" |Tee-Object -FilePath $logFile  -Append
    } else {
        $host.UI.RawUI.BackgroundColor = "Black"
        "$x,503 Service Unavailable,$CiscoIP,$CiscoPort,$URL"|Tee-Object -FilePath $logFile -Append
        $host.UI.RawUI.BackgroundColor = "DarkMagenta"
    }
  }
 } 