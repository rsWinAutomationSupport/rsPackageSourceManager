rsGit
=====
```PoSh
rsGit Git
{
    Name = "rsGit"
    Source = "https://github.com/rsWinAutomationSupport/rsGit.git"
    Destination = "C:\Program Files\WindowsPowerShell\Modules\"
    Branch = "master"
    Ensure = "Present"
}
rsGit Git1_0
{
    Name = "rsGit_1_0"
    Source = "https://github.com/rsWinAutomationSupport/rsGit.git"
    Destination = "C:\Program Files\WindowsPowerShell\Modules\1.0\"
    Branch = "v1.0"
    Ensure = "Present"
}
rsGit GitZip
{
    Name = "Git_Zip"
    Source = "https://github.com/rsWinAutomationSupport/rsGit.git"
    Destination = "C:\Program Files\WindowsPowerShell\Modules\"
    DestinationZip = "C:\Program Files\WindowsPowerShell\DscService\Modules"
    Branch = "v1.0"
    Ensure = "Present"
}
```