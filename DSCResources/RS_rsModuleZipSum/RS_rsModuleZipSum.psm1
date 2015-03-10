Function Get-TargetResource {
  param (
    [parameter(Mandatory = $true)]
    [string]$Name,
    [string]$modulePath,
    [string]$destination
  )
  
  return @{
    'path' = $modulePath
    'destination' = $destination
  }
}

Function Test-TargetResource {
  param (
    [parameter(Mandatory = $true)]
    [string]$Name,
    [string]$modulePath,
    [string]$destination
  )
  
  $modules = (Get-Item -Path $(Join-Path $modulePath -ChildPath '*')).BaseName
  $testResult = $false
  if($modules) {
    foreach($module in $modules) {
      if(Test-Path -Path $((Join-Path $modulePath -ChildPath $module), '\', $($module, '.psd1' -join '') -join '')) {
        $moduleName = $($module, '_', $(((Get-Content -Path $((Join-Path $modulePath -ChildPath $module), $($module, ".psd1" -join '') -join '\')) -match "ModuleVersion") -replace 'ModuleVersion', '' -replace ' ', '' -replace '=', '' -replace "'", '') -join '')

        if(Test-Path -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip' -join ''))) {
          if($((Get-FileHash -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip' -join '')) -ErrorAction SilentlyContinue).Hash) -eq $(Get-Content -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip.checksum' -join '')) -ErrorAction SilentlyContinue)) {
            $testResult = $true
          }

          else {
            return $false
          }
        }
      }
    }
    if($testResult -eq $true) {
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

Function Set-TargetResource {
  param (
    [parameter(Mandatory = $true)]
    [string]$Name,
    [string]$modulePath,
    [string]$destination
  )
  
  $modules = (Get-Item -Path $(Join-Path $modulePath -ChildPath '*')).BaseName
  if($modules) {
    foreach($module in $modules) {
      if(Test-Path -Path $((Join-Path $modulePath -ChildPath $module), '\', $($module, '.psd1' -join '') -join '')) {
        $moduleName = $($module, '_', $(((Get-Content -Path $((Join-Path $modulePath -ChildPath $module), $($module, ".psd1" -join '') -join '\')) -match "ModuleVersion") -replace 'ModuleVersion', '' -replace ' ', '' -replace '=', '' -replace "'", '') -join '')
        if(!(Test-Path -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip' -join ''))) -or !($((Get-FileHash -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip' -join '')) -ErrorAction SilentlyContinue).Hash) -eq $(Get-Content -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip.checksum' -join '')) -ErrorAction SilentlyContinue))) {
          Remove-Item -Path $((Join-Path $destination -ChildPath $module), '*' -join '') -Force
          if($module -ne "PowerShellAccessControl") {
            Compress-Archive -Path $(Join-Path $modulePath -ChildPath $module) -DestinationPath $((Join-Path $destination -ChildPath $moduleName), '.zip' -join '') -ErrorAction SilentlyContinue
            Set-Content -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip.checksum' -join '')) -Value $((Get-FileHash -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip' -join ''))).Hash)
          }
        }
      }
    }
  }
}

Export-ModuleMember -Function *-TargetResource