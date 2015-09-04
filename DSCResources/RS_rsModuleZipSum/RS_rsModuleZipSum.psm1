Function Get-TargetResource {
  param (
    [parameter(Mandatory = $true)]
    [string]$Name,
    [string]$modulePath,
    [string]$destination
  )
  
  @{
     'modulePath' = $modulePath
     'destination' = $destination
     'Name' = $Name
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
    $testResult = $true
    if($modules) {
        foreach($module in $modules) {
            if(Test-Path -Path $((Join-Path $modulePath -ChildPath $module), '\', $($module, '.psd1' -join '') -join '')) {
                $moduleName = $($module, '_', $(((Get-Content -Path $((Join-Path $modulePath -ChildPath $module), $($module, ".psd1" -join '') -join '\')) -match "ModuleVersion") -replace 'ModuleVersion', '' -replace ' ', '' -replace '=', '' -replace "'", '' -replace '"', '').Trim() -join '')
                if(Test-Path -Verbose -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip' -join ''))) {
                    if($((Get-FileHash -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip' -join '')) -ErrorAction SilentlyContinue).Hash) -eq $(Get-Content -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip.checksum' -join '')) -ErrorAction SilentlyContinue)) {
                        #$testResult = $true
                    }
                    else {
                        $testResult = $false
                    }
                }
                else{
                    Write-Verbose "Missing $module"
                    $testresult = $false
                }
            }
        }
    }
    return $testResult
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
                $moduleName = $($module, '_', $(((Get-Content -Path $((Join-Path $modulePath -ChildPath $module), $($module, ".psd1" -join '') -join '\')) -match "ModuleVersion") -replace 'ModuleVersion', '' -replace ' ', '' -replace '=', '' -replace "'", '' -replace '"', '').Trim() -join '')
                if(!(Test-Path -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip' -join ''))) -or !($((Get-FileHash -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip' -join '')) -ErrorAction SilentlyContinue).Hash) -eq $(Get-Content -Path $(Join-Path $destination -ChildPath $($moduleName, '.zip.checksum' -join '')) -ErrorAction SilentlyContinue))) {
                    Remove-Item -Path $((Join-Path $destination -ChildPath $module), '*' -join '') -Force
                    if($module -ne "PowerShellAccessControl") {
                        New-ResourceZip -modulePath $(Join-Path $modulePath -ChildPath $module) -outputDir $destination
                    }
                }
            }
        }
    }
    New-DSCCheckSum -ConfigurationPath $destination -Force
}
Function New-ResourceZip
{
    param
    (
        $modulePath,
        $outputDir
    )
    #Read the module name & version
    $module = Import-Module $modulePath -PassThru
    $moduleName = $module.Name
    $version = $module.Version.ToString()
    Remove-Module $moduleName
   
    $zipFilename = ("{0}_{1}.zip" -f $moduleName, $version)
    $outputPath = Join-Path $outputDir $zipFilename
    if ( -not (Test-Path $outputPath) ) 
    { 
        # Code to create an 'acceptable' structured ZIP file for DSC
        # Courtesy of: @Neptune443 (http://blog.cosmoskey.com/powershell/desired-state-configuration-in-pull-mode-over-smb/)
        [byte[]]$data = New-Object byte[] 22
        $data[0] = 80
        $data[1] = 75
        $data[2] = 5
        $data[3] = 6
        [System.IO.File]::WriteAllBytes($outputPath, $data)
        $acl = Get-Acl -Path $outputPath
      
        $shellObj = New-Object -ComObject "Shell.Application"
        $zipFileObj = $shellObj.NameSpace($outputPath)
        if ($zipFileObj -ne $null)
        {
            $target = get-item $modulePath
            # CopyHere might be async and we might need to wait for the Zip file to have been created full before we continue
            # Added flags to minimize any UI & prompts etc.
            $zipFileObj.CopyHere($target.FullName, 0x14)
            do 
            {
            $zipCount = $zipFileObj.Items().count
            Start-sleep -Milliseconds 50
            }
            While ($zipFileObj.Items().count -lt 1)
            [Runtime.InteropServices.Marshal]::ReleaseComObject($zipFileObj) | Out-Null
            Set-Acl -Path $outputPath -AclObject $acl
        }
        else
        {
            Throw "Failed to create the zip file"
        }
    }
    else
    {
        $outputPath = $null
    }
   
    return $outputPath
}
Export-ModuleMember -Function *-TargetResource