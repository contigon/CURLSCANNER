Clear-Host

$Help = @"

SHODAN SEARCH AND DOWNLOAD Querie/Dorks listed in a File
---------------------------------------------------------

1.Download the queries/dorks that are listed in a file
2.The searches will automatically download all data related to Israel ("country:il").
3.Convert the JSON.GZ files to CSV
4.Combine the files to one CSV file
5.Remove Duplicates and export to IP/PORT/PROTOCOL(UDP/TCP) file (ip.csv)

NOTE: You need to have a INCDKEYS.xml file which includes the SHODAN API KEY in the script directory.

"@

Write-Host $Help -ForegroundColor Yellow
$input =  Read-Host "Press Enter to continue or (q) to quit"
if ($input -eq "q") {
    break
}

#Install-Module -Name ImportExcel -Scope CurrentUser -Force
$apikey = Import-Clixml -Path $PSScriptRoot\INCDKEYS.xml
shodan init $apikey
$FileDate = Get-Date -Format "ddMMyyyy"
$country = "country:IL"
$OutputFolder = "$PSScriptRoot\Downloads"
$OutputFileType = "csv"
$ShodanDorkFile = "$PSScriptRoot\SHODAN-DORKS.txt"
$ShodanLogFile = "$PSScriptRoot\ShodanLog-$FileDate.txt"
$Seperatoer = "--------------------------------------------------------------------------"

New-Item -Path $OutputFolder -ItemType Directory -ErrorAction SilentlyContinue

foreach($Dork in [System.IO.File]::ReadLines($ShodanDorkFile))
{
      $ResultFile = ($Dork.Replace(":","_").replace("[","_").replace("]","_").replace("""","_")).replace(" ","_").replace("/","_").replace("-","_").replace(",","_").replace(".","_")
      $response = shodan download --limit -1 $ResultFile $Dork $country
      $response | Tee-Object -FilePath $ShodanLogFile -Append
      $Seperatoer| Tee-Object -FilePath $ShodanLogFile -Append
      
}

Move-Item "$PSScriptRoot\*.json.gz" -Destination $OutputFolder -Force

#Convert JSON files to CSV and merge all CSV's 
Push-Location $OutputFolder
(Get-ChildItem -File *.gz).FullName | foreach ($_){shodan convert $_ $OutputFileType}
# Get a list of the CSV files in a directory
$CSVFiles = Get-ChildItem -Path "." -Filter "*.$OutputFileType"
# Initialize an array to hold the data from the CSV files
$CSVData = @()
# Loop over each CSV file
ForEach ($CSVFile in $CSVFiles) {
    # Import the CSV file
    $CSVContent = Import-Csv -Path $CSVFile.FullName
 
    # Add the data from the CSV file to the array
    $CSVData += $CSVContent
}
# Now, $csvData contains the combined data from all the CSV files
$CSVData | Export-Csv -Path "_ShodanCombined-$FileDate.csv" -NoTypeInformation -Force
Pop-Location
 
$ShodanCombined = Import-Csv -Path "$OutputFolder\_ShodanCombined-$FileDate.$OutputFileType"
#$ShodanCombined | select ip_str,port,transport
#$ShodanCombined | foreach($_){$_.ip_str + ":" + $_.port +":" + $_.transport}

Import-Csv $ShodanCombined | sort ip_str,port,transport -Unique | Export-Csv "$OutputFolder\ip.csv" -NoTypeInformation -Force

