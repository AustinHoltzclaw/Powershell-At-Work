

Import-Module activedirectory

Clear-Host

function Get-LocalAdminToCsv {
  Param (
    $Path = (Get-ADDomain).DistinguishedName,
    $ComputerName = (Get-ADComputer -Filter * -Server (Get-ADDomain).DNsroot -SearchBase $Path -Properties Enabled | Where-Object {$_.Enabled -eq "True"})
    )
  Begin{
    [array]$Table = $null
    $Counter = 0
  }
  Process
  {
    $Date = Get-Date -Format MM_dd_yyyy_HH_mm_ss
    $FolderName = "LocalAdminsReport(" + $Date + ")"
    New-Item -Path ".\$FolderName" -ItemType Directory -Force | Out-Null
    
    foreach($Computer in $ComputerName)
    {
      try
      {
        $PC = Get-ADComputer $Computer
        $Name = $PC.Name
        $CountPC = @($ComputerName).count
      }
      catch{
        Write-Host "Cannot retrieve computer $Computer" -ForegroundColor Yellow -BackgroundColor Red
        Add-Content -Path ".\$FolderName\ErrorLog.txt" "$Name"
        continue
      }
      finally{
        $Counter ++
      }
      
      #This may be needed for better output if you work in a hybrid or remote workplace.
      try{
        Test-Connection $Name -Count 1 -ErrorAction Stop
      }
      catch{
        continue
      }
      
      Write-Progress -Activity "Connecting PC $Counter/$CountPC " -Status "Querying ($Name)" -PercentComplete (($Counter/$CountPC) * 100)
      
      #WinRM is required to run programs remotely on windows 10 machines. It takes up resources and works through a remote session.
      try{
        Write-Host "Checking WinRM on" $Name "..." -ForegroundColor Green
        $ServiceStatus = Get-Service -ComputerName $Name -Name WinRM
        if ($ServiceStatus -eq "Running"){
          Write-Host "WinRM Service is already running on" $Name "..." -ForegroundColor Green
        }
        else{
          Write-Host "Starting WinRM Service on " $Name "....." -ForegroundColor Yellow
          Get-Service -ComputerName $Name -Name WinRM | start-service
        } 
      }
      catch {
        Write-Host "Could not install WinRM on $Name"
        continue
      }
      
      try{
        $row = $null
        $members = [ASDI]"WinNT://$Name/Administrators"
        $members = @($members.psbase.Invoke("Members"))
        $members | foreach{
                    $User = $_.GetType().InvokeMember("Name", "GetProperty", $null, $_, $null)
                            $row += $User
                            $row += " ; "
                            }
        Write-Host "Computer ($Name) has been queried and exported." -ForegroundColor Green -BackgroundColor black
        
        $obj = New-Object -TypeName PSObject -Property @{
                        "Name" = $Name
                        "LocalAdmins" = $Row
                                         }
        $table += $obj
      }
      
      catch
      {
        Write-Host "Error accessing ($Name)" -ForegroundColor Yellow -BackgroundColor Red
        AddContent -Path ".\$FolderName\ErrorLog.txt" "$Name"
      }
      #This stops WinRM on the workstation for endpoint security.
      Get-Service -ComputerName $Name -Name WinRM | stop-service
      
      
      try{
        $Table | Sort Name | Select Name, LocalAdmins | Export-Csv -path ".\$FolderName\Report.csv"
      }
      catch{
        Write-Warning $_
      } 
    }
  }
  end{}
}
