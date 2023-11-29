Clear-Host

$apikey = Import-Clixml -Path $PSScriptRoot\INCDKEYS.xml
#shodan init $apikey

#  Get-Date -Format "ddd, dd MMM yyyy"

$StartDate = [Datetime]::ParseExact("Mon, 01 May 2023", "ddd, dd MMM yyyy", $null)
$EndDate = [Datetime]::ParseExact("Fri, 30 Jun 2023", "ddd, dd MMM yyyy", $null)

$i = 0
while($StartDate -ne $EndDate){
    
    $day = $StartDate.DayOfYear
    $DateToCheck =  $StartDate.tostring("ddd, dd MMM yyyy")
    $Dork = ("Server: xxxxxxxx-xxxxx country:IL http.html:'top.location=/remote/login' Last-Modified: '$DateToCheck'").Replace("'","""")
    $response = shodan download --limit -1 $day $Dork
    $StartDate = $StartDate.AddDays(1)

}



