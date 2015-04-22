Function Get-TargetResource {
  [OutputType([Hashtable])]
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name 
  )

  $packageInfo = Get-Package -Name $Name -ErrorAction SilentlyContinue
  if($packageInfo) {
    @{ 
      'Name' = $packageInfo.Name;
      'ProviderName' = $packageInfo.Providername;
      'Source' = $packageInfo.Source;
      'Result' = ($Name, $packageInfo.Version, $packageInfo.Status -join ' ') 
    }  
  }
  else {
    @{ 'Result' = "$Name NOT FOUND" }
  }
}
  

Function Test-TargetResource {
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,
    [string]$RequiredVersion,
    [string]$MinimumVersion,
    [string]$MaximumVersion,
    [string]$Ensure,
    [string]$ProviderName,
    [string]$Source
  )
  $packageInfo = Get-Package -Name $Name -ErrorAction SilentlyContinue
  $result = $false
  
  if($Ensure -eq "Present") {
    if($packageInfo) {
      if($MinimumVersion -and !$MaximumVersion) {
        if($packageInfo.Version -ge $MinimumVersion -and $packageInfo.Status -eq 'Installed') { 
          $result = $true
        }
        else {
          return $false
        }
        if($ProviderName) {
          if($packageInfo.Providername -eq $ProviderName) {
            $result = $true
          }
          else {
            return $false
          }
        }
        if($Source) {
          if($packageInfo.Source -eq $Source) {
            $result = $true
          }
          else {
            return $false
          }
        }
      }
      if($MinimumVersion -and $MaximumVersion) {
        if($packageInfo.Version -ge $MinimumVersion -and $packageInfo.Version -le $MaximumVersion -and $packageInfo.Status -eq 'Installed') {
          $result = $true
        }
        else {
          return $false
        }
        if($ProviderName) {
          if($packageInfo.Providername -eq $ProviderName) {
            $result = $true
          }
          else {
            return $false
          }
        }
        if($Source) {
          if($packageInfo.Source -eq $Source) {
            $result = $true
          }
          else {
            return $false
          }
        }
      }
      if($MaximumVersion -and !$MinimumVersion) {
        if($packageInfo.Version -le $MaximumVersion -and $packageInfo.Status -eq 'Installed') {
          $result = $true
        }
        else {
          return $false
        }
        if($ProviderName) {
          if($packageInfo.Providername -eq $ProviderName) {
            $result = $true
          }
          else {
            return $false
          }
        }
        if($Source) {
          if($packageInfo.Source -eq $Source) {
            $result = $true
          }
          else {
            return $false
          }
        }
      }
      if($RequiredVersion) {
        if($packageInfo.Version -eq $RequiredVersion -and $packageInfo.Status -eq 'Installed') {
          $result = $true
        }
        else {
          return $false
        }
        if($ProviderName) {
          if($packageInfo.Providername -eq $ProviderName) {
            $result = $true
          }
          else {
            return $false
          }
        }
        if($Source) {
          if($packageInfo.Source -eq $Source) {
            $result = $true
          }
          else {
            return $false
          }
        }
        if($result -eq $true) {
          return $true
        }
      }
      if($result -eq $true) {
        return $true
      }
      else {
        return $false
      }
    }
    else {
      return $false
    }
  }
  if($Ensure -eq "Absent") {
    if($packageInfo) {
      if($packageInfo.Status -eq "Installed") {
        return $false
      }
      else {
        return $true
      }
    }
    else {
      return $true
    } 
  }
}

Function Set-TargetResource {
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,
    [string]$RequiredVersion,
    [string]$MinimumVersion,
    [string]$MaximumVersion,
    [string][Parameter(Mandatory)][ValidateSet('Present','Absent')]$Ensure,
    [string]$ProviderName,
    [string]$Source
  )
  
  if($Ensure -eq "Absent") {
    if(Get-Package -Name $Name -ErrorAction SilentlyContinue) {
      try {
        Uninstall-Package -Name $Name -Force -ErrorAction SilentlyContinue
      }
      catch {
        Write-Verbose "failed to uninstall $Name $($_.Exception.Message)"
      }
    }
  }
  else {
    $PSBoundParameters.Remove('Ensure')
    try {
      Install-Package @PSBoundParameters -Force -ErrorAction SilentlyContinue
    }
    catch {
      Write-Verbose "failed to install $Name $($_.Exception.Message)"
    }
  }
}

Export-ModuleMember -Function *-TargetResource