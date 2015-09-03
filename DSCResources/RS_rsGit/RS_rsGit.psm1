function Get-TargetResource
{
    [OutputType([Hashtable])]
    param (
        [ValidateSet('Present','Absent')]
        [string]
        $Ensure = 'Present',
        [ValidateSet('Clone','CopyOnly')]
        [string]
        $Mode = 'Clone',
        [parameter(Mandatory = $true)]
        [string]
        $Source,
        [parameter(Mandatory = $true)]
        [string]
        $Destination,
        [parameter(Mandatory = $true)]
        [string]
        $Branch,
        [parameter(Mandatory = $true)]
        [string]
        $Name,
        [string]
        $DestinationZip,
        [bool]
        $Logging,
        [string]
        $GitPath
    )
    
    try
    {
        $myLogSource = $PSCmdlet.MyInvocation.MyCommand.ModuleName
        New-Eventlog -LogName "DevOps" -Source $myLogSource -ErrorAction SilentlyContinue
    }
    catch {}
    
    $RepoPath = (SetRepoPath -Source $Source -Destination $Destination)

    Write-Verbose "Checking if `"$RepoPath`" exists"

    if (Test-Path $RepoPath)
    {
        if (IsValidRepo -RepoPath $RepoPath -GitPath $GitPath)
        {
            Set-Location $RepoPath
            $ensureResult = "Present"
            
            # Retreive current branch and clean-up git output
            $currentBranch = (ExecGit -GitPath $GitPath -args "rev-parse --abbrev-ref HEAD").split()[0]
            Write-Verbose "Repo branch set to `"$currentBranch`""

            # Retrieve current repo origin fetch settings
            # Split output by line; find one that is listed as (fetch); split by space and list just origin URI
            $SourceResult = (((ExecGit -GitPath $GitPath -args "remote -v").Split("`n") | Where-Object { $_.contains("(fetch)") }) -split "\s+")[1]

            if (-not ([String]::IsNullOrEmpty($DestinationZip)))
            {
                if (Test-Path $DestinationZip)
                {
                    $currentDestZip = $DestinationZip
                }
                else
                {
                    $currentDestZip = $null
                }
            }
            else
            {
                $currentDestZip = $null
            }
        }
        else
        {
            $ensureResult = "Absent"
            $currentBranch = $null
            $Destination = $null
            $SourceResult = $null
            if ($DestinationZip)
            {
                $currentDestZip = $null
            }
        }
    }
    else
    {
        $ensureResult = "Absent"
        $currentBranch = $null
        $Destination = $null
        $SourceResult = $null
        if ($DestinationZip)
        {
            $DestinationZip = $null
        }
    }
    
    @{
        Name = $Name
        Destination = $Destination
        DestinationZip = $currentDestZip
        Source = $SourceResult
        Ensure = $ensureResult
        Branch = $currentBranch
        Mode = $Mode
    }  
}

function Set-TargetResource
{
    param (
        [ValidateSet('Present','Absent')]
        [string]
        $Ensure = 'Present',
        [ValidateSet('Clone','CopyOnly')]
        [string]
        $Mode = 'Clone',
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Source,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Destination,
        [parameter(Mandatory = $true)]
        [string]
        $Branch,
        [parameter(Mandatory = $true)]
        [string]
        $Name,
        [string]
        $DestinationZip,
        [bool]
        $Logging,
        [string]
        $GitPath
    )
    try
    {
        $myLogSource = $PSCmdlet.MyInvocation.MyCommand.ModuleName
        New-Eventlog -LogName "DevOps" -Source $myLogSource -ErrorAction SilentlyContinue
    }
    catch {}

    $RepoPath = (SetRepoPath -Source $Source -Destination $Destination)
    
    if ($Ensure -eq "Present")
    {
        $GetResult = (Get-TargetResource -Ensure $Ensure -Source $Source -Destination $Destination -Branch $Branch -Name $Name -GitPath $GitPath)
        
        # Retrieve any changes, which have not been merged locally
        $Fetch = ExecGit -GitPath $GitPath -args "fetch origin"

        # Check repository is already configured as per desired configuration
        if (($GetResult.Ensure -ne "Present") -or 
            ($GetResult.Source -ne $Source) -or 
            ($GetResult.Destination -ne $Destination))
        {
            if (-not (Test-Path $Destination))
            {
                New-Item $Destination -ItemType Directory -Force
            }
            Set-Location $Destination
            
            if (Test-Path $RepoPath)
            {
                Remove-Item -Path $RepoPath -Recurse -Force
            }

            $GitOutput = (ExecGit -GitPath $GitPath -args "clone --branch $branch $Source")
            if($Logging) 
            {
                Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Information -EventId 1000 -Message ("Repo: $Name`ngit clone --branch $branch $Source `n$GitOutput") 
            }
            Write-Verbose "git clone --branch $branch $Source `n$GitOutput"
        }
        else
        {
            Set-Location $RepoPath

            # Verify that we are using the correct branch and force-set the correct one - this will destroy any uncommited changes!
            if ($GetResult.Branch -ne $Branch)
            {
                Write-Verbose "Local branch is not valid - setting to `"$Branch`""
                $GitOutput = (ExecGit -GitPath $GitPath -args "checkout --force $Branch")
                if($Logging) 
                {
                    Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Information -EventId 1000 -Message ("Repo: $Name`nLocal branch is not valid - setting to `"$Branch`" `ngit checkout --force $Branch `n$GitOutput") 
                }
                Write-Verbose "`ngit checkout --force $Branch `n$GitOutput"
            }

            $RepoStatus = ExecGit -GitPath $GitPath -args "status"

            if ($Mode -eq "Clone")
            {
                if (($localCommit -ne $originCommit) -or (-not $RepoStatus.Contains("branch is up-to-date")))
                {
                    # merge remote changes if local is behind origin seems to not work very well during provisioning - need to investigate further
                    $GitOutput = ExecGit -GitPath $GitPath -args "merge remotes/origin/$Branch"
                    $RepoStatus = ExecGit -GitPath $GitPath -args "status"

                    if($Logging) 
                    {
                        Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Warning -EventId 1000 -Message ("Repo: $Name`nLocal repo is behind origin/$Branch :`ngit merge remotes/origin/$Branch :`n $GitOutput") 
                        #Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Warning -EventId 1000 -Message ("Repo: $Name`nLocal repo is behind origin/$Branch :`ngit reset --hard origin/$branch :`n $GitOutput") 
                    }
                    Write-Verbose "Local repo is behind origin/$Branch :`ngit merge remotes/origin/$branch :`n $GitOutput"
                }

                # Check if local repo has changes that are not in origin and reset the repo to origin.
                # Each test-case below will currently result in local repo being hard reset to match origin.
                # Effectively any local changes to repo will be lost:
                #
                # "Your branch is ahead of" - local repo contains commits, which have not been merged with remote yet 
                # "no changes added to commit" - a tracked file has been modified locally, but has not been commited yet
                # "have diverged" - local and remote have at least one unmerged commit each, these must be merged before we can continue
                # "Changes to be committed" - local repo has staged files, which have not been commited yet
                #
                if (($RepoStatus.Contains("Your branch is ahead of")) -or
                    ($RepoStatus.Contains("no changes added to commit")) -or 
                    ($RepoStatus.Contains("have diverged")) -or 
                    ($RepoStatus.Contains("Changes to be committed")))
                {
                    # Reset local repo to match origin for all tracked files
                    $GitOutput = ExecGit -GitPath $GitPath -args "reset --hard origin/$branch"
                    $RepoStatus = ExecGit -GitPath $GitPath -args "status"

                    if($Logging) 
                    {
                        Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Information -EventId 1000 -Message ("Repo: $Name`nLocal changes made to repo - resetting repo: git reset --hard origin/$Branch `n $GitOutput") 
                    }
                    
                    Write-Verbose "Local changes made to repo - resetting repo: git reset --hard origin/$Branch `n $GitOutput"
                }

                if (-not ($RepoStatus.Contains("working directory clean")))
                {
                    # Remove any untracked files (-f [force], directories (-d) and any ignored files (-x)
                    $GitOutput = ExecGit -GitPath $GitPath -args "clean -xdf"
                    $RepoStatus = ExecGit -GitPath $GitPath -args "status"

                    if($Logging) 
                    {
                        Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Information -EventId 1000 -Message ("Repo: $Name`nLocal repo contains uncommited changes! `n$RepoStatus `n git clean -xdf `n $GitOutput") 
                    }
                    Write-Verbose "Local repo contains uncommited changes! `n$RepoStatus `n git clean -xdf `n $GitOutput"
                }
            }
            
            if ($Mode -eq "CopyOnly")
            {
                if($Logging) 
                {
                    Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Information -EventId 1000 -Message ("Repo: $Name`nCopyOnly mode set - no need to sync: `n $GitOutput") 
                }
                
                Write-Verbose "CopyOnly mode set - no need to sync: `n $GitOutput"
            }

        }

        if ( -not ([String]::IsNullOrEmpty($DestinationZip)) )
        {
            if($Logging -eq $true) 
            {
                Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Information -EventId 1000 -Message ("Starting Resource Zip: $DestinationZip ") 
            }

            $resourceZipPath = New-ResourceZip -modulePath $RepoPath -outputDir $DestinationZip 
            
            if ( $resourceZipPath -ne $null )
            {
                if($Logging -eq $true) { Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Information -EventId 1000 -Message ("Repo: $Name`nStarting Checksum") }
                Remove-Item -Path ($resourceZipPath + ".checksum") -Force -ErrorAction SilentlyContinue
                New-Item -Path ($resourceZipPath + ".checksum") -ItemType file
                $hash = (Get-FileHash -Path $resourceZipPath).Hash
                [System.IO.File]::AppendAllText(($resourceZipPath + '.checksum'), $hash)
            }
        }
    }

    if ($Ensure -eq "Absent")
    {
        Write-Verbose "Removing $RepoPath"
        if($Logging -eq $true) 
        {
            Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Information -EventId 1000 -Message ("Repo: $Name`nRemoving $RepoPath")
        }
        Remove-Item -Path $RepoPath -Recurse -Force

        Write-Verbose "Checking if $Destination is empty..."
        if ((Get-ChildItem $Destination | Measure-Object).count -eq 0)
        {
            Remove-Item -Path $Destination -Recurse -Force
            Write-Verbose "$Destination removed"
            if($Logging -eq $true) 
            {
                Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Information -EventId 1000 -Message ("Repo: $Name`nRemoving $Destination")
            }
        }
        else
        {
            Write-Verbose "$Destination not empty - leaving alone..."
            if($Logging -eq $true) 
            {
                Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Information -EventId 1000 -Message ("Repo: $Name`n$Destination was not empty, so was not removed")
            }
        }
    # TODO: $DestinationZip removal
    }
}

function Test-TargetResource
{
    [OutputType([boolean])]
    param (
        [ValidateSet('Present','Absent')]
        [string]
        $Ensure = 'Present',
        [ValidateSet('Clone','CopyOnly')]
        [string]
        $Mode = 'Clone',
        [parameter(Mandatory = $true)]
        [string]
        $Source,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Destination,
        [parameter(Mandatory = $true)]
        [string]
        $Branch,
        [parameter(Mandatory = $true)]
        [string]
        $Name,
        [string]
        $DestinationZip,
        [bool]
        $Logging,
        [string]
        $GitPath
    )

    try
    {
        $myLogSource = $PSCmdlet.MyInvocation.MyCommand.ModuleName
        New-Eventlog -LogName "DevOps" -Source $myLogSource -ErrorAction SilentlyContinue
    }
    catch {}

    $RepoPath = (SetRepoPath -Source $Source -Destination $Destination)

    $GetResult = (Get-TargetResource -Ensure $Ensure -Source $Source -Destination $Destination -Branch $Branch -Name $Name -GitPath $GitPath)

    if ($Ensure -eq "Present")
    {
        if (Test-Path $RepoPath)
        {
            Set-Location $RepoPath
            if (($GetResult.Destination -eq $Destination) -and ($GetResult.Source -eq $Source) -and ($GetResult.Branch -eq $Branch))
            {
                if ($Mode -eq "Clone")
                {
                    # Check if origin contains changes which have not been merged locally
                    $Fetch = ExecGit -GitPath $GitPath -args "fetch origin"
                    if ($Fetch.Length -ne 0)
                    {
                        Write-Verbose "origin/$Branch has pending updates:`n$Fetch"
                        if($Logging -eq $true) 
                        {
                            Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Warning -EventId 1000 -Message ("Repo: $Name`norigin/$Branch has pending updates:`n$Fetch")
                        }
                        return $false
                    }
                    
                    # Ensure that local and remote commits match after a fetch operation has been made
                    $localCommit = ExecGit -GitPath $GitPath -args "rev-parse HEAD"
                    $originCommit = ExecGit -GitPath $GitPath -args "rev-parse origin/$Branch"

                    if (-not ($localCommit -eq $originCommit))
                    {
                        Write-Verbose "Latest local commit does not match origin/$Branch"
                        if($Logging -eq $true) 
                        {
                            Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Warning -EventId 1000 -Message ("Repo: $Name`nLatest local commit does not match origin/$Branch")
                        }
                        return $false
                    }
                    
                    Write-Verbose "Repo mode set as `"$Mode`", checking for local changes"
                    
                    # Check for local repo status for local uncommited changes
                    # TODO: for push mode we will need tests for local commits, which have not been pushed yet
                    $RepoStatus = ExecGit -GitPath $GitPath -args "status"
                    if (-not ($RepoStatus.Contains("working directory clean")))
                    {
                        Write-Verbose "Local repo contains uncommited changes! `n$RepoStatus"
                        if($Logging -eq $true) 
                        {
                            Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Warning -EventId 1000 -Message ("Repo: $Name`nLocal repo contains uncommited changes! `n$RepoStatus")
                        }
                        return $false
                    }
                    else
                    {
                        Write-Verbose "All tests passed, repo test result is true: `n$RepoStatus"
                        if($Logging -eq $true) 
                        {
                            Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Information -EventId 1000 -Message ("Repo: $Name`nAll tests passed, repo test result is true: `n$RepoStatus")
                        }
                        return $true
                    }
                }
                else
                {
                    return $true
                }
            }
            else
            {
                Write-Verbose "Repository settings are not consistent. `n $($GetResult | Out-String)"
                if($Logging -eq $true) 
                {
                    Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Warning -EventId 1000 -Message ("Repo: $Name`nRepository settings are not consistent. `n $($GetResult | Out-String)")
                }
                return $false
            }
        }
        else
        {
            Write-Verbose "$RepoPath is not found!"
            if($Logging -eq $true) 
            {
                Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Warning -EventId 1000 -Message ("Repo: $Name`n$RepoPath is not found")
            }
            return $false
        }
    }
    else
    {
        if (Test-Path $RepoPath)
        {
            Write-Verbose "$RepoPath still exists"
            if($Logging -eq $true) 
            {
                Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Warning -EventId 1000 -Message ("Repo: $Name`n$RepoPath still exists")
            }
            return $false
        }
        else
        {
            Write-Verbose "$RepoPath does not exist"
            if($Logging -eq $true) 
            {
                Write-EventLog -LogName DevOps -Source $myLogSource -EntryType Information -EventId 1000 -Message ("Repo: $Name`n$RepoPath does not exist")
            }
            return $true
        }
    }

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

function ExecGit
{
	param(
		[string]$GitPath,
        [Parameter(Mandatory = $true)][string]$args
	)

    if (-not $GitPath)
    {
        $GitPath = (Get-Command git.exe).Path
    }

    if (-not (Test-Path $GitPath))
    {
        Throw "Git executable not found at $GitPath"
    }

    $location = Get-Location

    try
    {
        #Check if location specified for git executable is valid
	    if ((Get-Command $GitPath).Name -eq "git.exe")
	    {
	    	# Write-Verbose "Executing: git $args in $($location.path)"
	        # Capture git output
	        $psi = New-object System.Diagnostics.ProcessStartInfo 
	        $psi.CreateNoWindow = $true 
	        $psi.UseShellExecute = $false 
	        $psi.RedirectStandardOutput = $true 
	        $psi.RedirectStandardError = $true 
	        $psi.FileName = $GitPath
            $psi.WorkingDirectory = $location.ToString()
	        $psi.Arguments = $args
	        $process = New-Object System.Diagnostics.Process 
	        $process.StartInfo = $psi
	        $process.Start() | Out-Null
	        $process.WaitForExit()
	        $output = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()

	        return $output
	    }
	    else
	    {
            Write-Verbose "Git executable not found at $GitPath"
            Throw "Git executable not found at $GitPath"
	    }
    }
    catch
    {
        Write-Verbose "Git client execution failed with the following error:`n $($Error[0].Exception)"
        return $($Error[0].Exception)
    }
}

function SetRepoPath
{
    param (
        [Parameter(Position=0,Mandatory = $true)][string]$Source,
        [Parameter(Position=1,Mandatory = $true)][string]$Destination
    )

    $RepoPath = Join-Path $Destination -ChildPath ($Source -replace "\.git$").Split("/")[-1]
    
    return $RepoPath
}

function IsValidRepo
{
    param(
		[string]$GitPath,
        [Parameter(Mandatory = $true)][string]$RepoPath
	)

    if (Test-Path $RepoPath)
    {
        Set-Location $RepoPath
        $output = (ExecGit -GitPath $GitPath -args "status")
        if ($output -notcontains "Not a git repository")
        {
            return $true
        }
        else
        {
            return $false
        }
    }
    else
    {
        return $false
    }
}

Export-ModuleMember -Function *-TargetResource