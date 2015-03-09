Function Get-TargetResource {
   param (
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Name,
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Repo,
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$PayloadURL,
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Ensure,
      [bool]$Logging
   )
   Import-Module rsCommon
   $logSource = $PSCmdlet.MyInvocation.MyCommand.ModuleName
   New-rsEventLogSource -logSource $logSource
   $d = Get-Content 'C:\DevOps\secrets.json' | ConvertFrom-Json
   try {
      $currentHooks = Invoke-rsRestMethod -Uri $("https://api.github.com/repos", $($d.git_username), $Repo, "hooks" -join '/') -Headers @{"Authorization" = "token $($d.git_Oauthtoken)"} -ContentType application/json -Method Get
   }
   catch {
      if($Logging) {
         Write-EventLog -LogName DevOps -Source $logSource -EntryType Error -EventId 1002 -Message "Failed to retrieve github webhooks `n $($_.Exception.Message)"
      }
   }
   @{
   Name = $Name
   Repo = $Repo
   PayloadURL = $PayloadURL
   Ensure = $Ensure
   Logging = $Logging
   }
   
}

Function Test-TargetResource {
   param (
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Name,
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Repo,
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$PayloadURL,
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Ensure,
      [bool]$Logging
   )
   Import-Module rsCommon
   $logSource = $PSCmdlet.MyInvocation.MyCommand.ModuleName
   New-rsEventLogSource -logSource $logSource 
   $d = Get-Content 'C:\DevOps\secrets.json' | ConvertFrom-Json
   try {
      $currentHooks = Invoke-rsRestMethod -Uri $("https://api.github.com/repos", $($d.git_username), $Repo, "hooks" -join '/') -Headers @{"Authorization" = "token $($d.git_Oauthtoken)"} -ContentType application/json -Method Get
   }
   catch {
      if($Logging) {
         Write-EventLog -LogName DevOps -Source $logSource -EntryType Error -EventId 1002 -Message "Failed to retrieve github webhooks `n $($_.Exception.Message)"
      }
   }
   $exists = $false
   foreach( $currentHook in $currentHooks )
   {
      if ( $currentHook.config.url -eq $PayloadURL)
      {
         $exists = $true
      }
   }
   if( $exists -eq $true -and $Ensure -eq "Absent" ) { return $false }
   if( $exists -eq $false -and $Ensure -eq "Present" ) { return $false }
   
   return $true
}

Function Set-TargetResource {
   param (
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Name,
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Repo,
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$PayloadURL,
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Ensure,
      [bool]$Logging
   )
   Import-Module rsCommon
   $d = Get-Content 'C:\DevOps\secrets.json' | ConvertFrom-Json
   . "$("C:\DevOps", $d.mR, "PullServerInfo.ps1" -join '\')"
   try {
      $currentHooks = Invoke-rsRestMethod -Uri $("https://api.github.com/repos", $($d.git_username), $Repo, "hooks" -join '/') -Headers @{"Authorization" = "token $($d.git_Oauthtoken)"} -ContentType application/json -Method Get
   }
   catch {
      if($Logging) {
         Write-EventLog -LogName DevOps -Source $logSource -EntryType Error -EventId 1002 -Message "Failed to retrieve github webhooks `n $($_.Exception.Message)"
      }
   }
   foreach($currentHook in $currentHooks) {
      try {
         if( $currentHook.config.url -eq $PayloadURL )
         {
            Invoke-rsRestMethod -Uri $("https://api.github.com/repos", $($d.git_username), $Repo, "hooks", $($currentHook.id) -join '/') -Headers @{"Authorization" = "token $($d.git_Oauthtoken)"} -ContentType application/json -Method Delete
         }
      }
      catch {
         if($Logging) {
            Write-EventLog -LogName DevOps -Source $logSource -EntryType Error -EventId 1002 -Message "Failed to DELETE github webhook(s) `n $($_.Exception.Message)"
         }
      }
   }
   if($Ensure -eq "Present") {
      $body = @{"name" = "web"; "active" = "true"; "events" = @("push"); "config" = @{"url" = $PayloadURL; "content_type" = "json"} } | ConvertTo-Json -Depth 3
      try {
         Invoke-rsRestMethod -Uri $("https://api.github.com/repos", $($d.git_username), $($d.mR), "hooks" -join '/') -Body $body -Headers @{"Authorization" = "token $($d.git_Oauthtoken)"} -ContentType application/json -Method Post
      }
      catch {
         Write-EventLog -LogName DevOps -Source $logSource -EntryType Error -EventId 1002 -Message "Failed to create github Webhook `n $($_.Exception.Message)"
      }
   }
}
Export-ModuleMember -Function *-TargetResource