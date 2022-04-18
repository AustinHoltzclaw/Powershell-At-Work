Import-Module ActiveDirectory
Import-Module ".\Get-LocalAdminToCsv.psm1"

$strFileName1 = ".\ErrorLog-Get-LocalAdminToCsv.txt"
Get-LocalAdminToCsv -Path "OU=yourOU, OU=otherOUs, DC=subdomain, DC=domain"
