$data = Import-Csv CiscoImplantV2Log-27-10-2023.txt

$Implanted = $data | where-Object Result -EQ "Implanted"
$Unavailable = $data | where-Object Result -EQ "503 Service Unavailable"
$OK = $data | where-Object Result -EQ "200-OK"
$Timeout = $data | where-Object Result -EQ "Timeout"
$InternalServerError = $data | where-Object Result -EQ "InternalServerError"


Write-Host "Implanted:" $Implanted.Count -ForegroundColor Red
Write-Host "200 OK =" $OK.Count -ForegroundColor Red
Write-Host "503 Service Unavailable:" $Unavailable.Count -ForegroundColor Green
Write-Host "Timeout:" $Timeout.Count -ForegroundColor Green
Write-Host "Internal Server Error:" $InternalServerError.Count -ForegroundColor Green
Write-Host "TOTAL DEVICES:" $data.Count -ForegroundColor Yellow

