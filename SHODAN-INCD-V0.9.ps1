Clear-Host

#Install-Module -Name ImportExcel -Scope CurrentUser -Force

function Open-File([string] $initialDirectory){

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.title = "Please choose the SHODAN QUERY/DORKs lists .txt file"
    $OpenFileDialog.filter = "All files (*.txt)| *.txt"
    $OpenFileDialog.ShowDialog() |  Out-Null

    return $OpenFileDialog.filename
} 

$Help = @"

SHODAN SEARCH AND DOWNLOAD Querie/Dorks listed in a File
---------------------------------------------------------

1.Download the queries/dorks that are listed in a file
2.The searches will automatically download all data related to Israel ("country:il").
3.Convert the JSON.GZ files to xlsx
4.Convert the xlsx files to csv files
5.Combine the files to one csv file
6.Remove Duplicates and export to IP/PORT/PROTOCOL(UDP/TCP) file (ip.csv)

NOTE: You need to have a INCDKEYS.xml file which includes the SHODAN API KEY in the script directory.

"@

Write-Host $Help -ForegroundColor Yellow

<#
$input =  Read-Host "Press Enter to continue or (q) to quit"
if ($input -eq "q") {
    break
}
#>


Write-Host "Please choose the SHODAN DORKS/QUERY lists file:"
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

$apikey = Import-Clixml -Path $PSScriptRoot\INCDKEYS.xml
#shodan init $apikey
$FileDate = Get-Date -Format "ddMMyyyy"
#$country = "country:IL"
$OutputFolder = "$PSScriptRoot\Downloads"
$ShodanDorkFile = $OpenFile
$ShodanLogFile = "$PSScriptRoot\ShodanLog-$FileDate.txt"
$Seperatoer = "--------------------------------------------------------------------------"


foreach($Dork in [System.IO.File]::ReadLines($ShodanDorkFile))
{
      #Write-Host $Dork -ForegroundColor Yellow
      $ResultFile = ($Dork.Replace(":","_").replace("[","_").replace("]","_").replace("""","_")).replace(" ","_").replace("/","_").replace("-","_").replace(",","_").replace(".","_")
      #Write-Host $ResultFile -ForegroundColor Blue
      $response = shodan download --limit -1 $ResultFile $Dork Country:IL

      $response | Tee-Object -FilePath $ShodanLogFile -Append
      $Seperatoer| Tee-Object -FilePath $ShodanLogFile -Append
      
}

New-Item -Path $OutputFolder -ItemType Directory -ErrorAction SilentlyContinue
Move-Item "$PSScriptRoot\*.json.gz" -Destination $OutputFolder -Force

#Convert JSON files to xlsx
Push-Location $OutputFolder
(Get-ChildItem -File *.gz).BaseName | foreach ($_.gz){

    shodan convert "$_.gz" xlsx
    $CsvFileName = $_.TrimEnd(".json")
    $CsvFileName
    $xlsFile = Import-Excel -Path "$CsvFileName.xlsx"
    $xlsFile | Export-Csv -Path "$CsvFileName.csv" -NoTypeInformation

    }

# Get a list of the CSV files in a directory
$CSVFiles = Get-ChildItem -Path "." -Filter "*.csv"
# Initialize an array to hold the data from the CSV files
$CSVData = @()
# Loop over each CSV file
ForEach ($CSVFile in $CSVFiles) {
    # Import the CSV file
    $CSVContent = Import-Csv -Path $CSVFile.FullName
 
    # Add the data from the CSV file to the array
    $CSVData += $CSVContent
}
# Now $csvData contains the combined data from all the CSV files
$CSVData | Export-Csv -Path "ShodanCombined-$FileDate.csv" -NoTypeInformation -Force

 
$ShodanCombined = Import-Csv -Path "ShodanCombined*.csv"
(($ShodanCombined | sort ip,port,transport -Unique) | select ip,port,transport) | Export-Csv "$OutputFolder\ip.csv" -NoTypeInformation -Force

#$ShodanCombine

Pop-Location