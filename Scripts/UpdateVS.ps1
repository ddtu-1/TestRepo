param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InstallChannelUri,
    
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoName,
    
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AccessToken    
)

$LogsFolder = "c:\workspace\$RepoName\Logs"
$UpdateVSLogFile = "$logsFolder\UpdateVS.log"
$ResultFile = "$logsFolder\ExitCode.log"

function Invoke-GitCommand {
    [CmdletBinding()]
    param([string]$params)

    $env:GIT_REDIRECT_STDERR = '2>&1'
    $commandLine = "C:\'Program Files'\Git\cmd\git.exe " + $params
    #Add-Content -Path $UpdateVSLogFile -Force -Value $commandLine

    Invoke-Expression $commandLine
    if ($LASTEXITCODE -ne 0) {
        $errMessage = "`r`nRunning $commandLine failed with exit code $LASTEXITCODE"
        Add-Content -Path $updateVSLogFile -Force -Value $errMessage
    }
}

# Stop all devenv related processes
$vs = Get-Process devenv -ErrorAction SilentlyContinue
if ($vs) {
    $vs.CloseMainWindow()
    Start-Sleep -Seconds 5
    if (!$vs.HasExited) {
        $vs | Stop-Process -Force
    }
}

Get-Process Microsoft.ServiceHub.Controller -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process serviceHub.IdentityHost -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process serviceHub.VSDetouredHost -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process serviceHub.SettingsHost -ErrorAction SilentlyContinue | Stop-Process -Force

$vsOriginalVersion = (Get-Item C:\VisualStudio\Common7\IDE\devenv.exe).VersionInfo.FileVersion
$startTime = Get-Date
$log = $startTime.ToString("yyyy-MM-ddTHH:mm:ss") + " Started upgrading via VSInstanceManager. `r`n"
$log += "InstallChannelUri - $InstallChannelUri"
Set-Content -Path $UpdateVSLogFile -Force -Value $log

$vsInstanceManagerPath = "C:\vsonline\vsoagent\bin\VSInstanceManager.exe"
$installProcess = Start-Process $vsInstanceManagerPath -ArgumentList "update --installChannelUri `"$InstallChannelUri`"" -PassThru
$installProcess.WaitForExit()
$exitCode = $installProcess.ExitCode

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalMinutes
$log = $endTime.ToString("yyyy-MM-ddTHH:mm:ss") + " Completed after $duration minutes."
Add-Content -Path $UpdateVSLogFile -Force -Value $log
Set-Content -Path $ResultFile -Force -Value $exitCode

$vsUpdatedVersion = (Get-Item C:\VisualStudio\Common7\IDE\devenv.exe).VersionInfo.FileVersion

if ($exitCode -eq 0 -or $exitCode -eq 3010) {
    $log = "`r`nSuccessfully upgraded VS Server from $vsOriginalVersion to $vsUpdatedVersion `r`nExit code - $exitCode `r`n"
}
else {
    $log = "`r`nFailed updating VS Server from $vsOriginalVersion to $vsUpdatedVersion `r`nExit code - $exitCode `r`n"
}

if ($exitCode -eq 3010) {
    $log += "`r`nRebooting machine..."
}
Add-Content -Path $UpdateVSLogFile -Force -Value $log

###
Set-Location "c:\workspace"
Invoke-GitCommand "clone https://$($AccessToken):x-oauth-basic@github.com/ddtu-1/$RepoName TestRepoLogs"

$dest = "c:\workspace\TestRepoLogs"
Set-Location $dest
Invoke-GitCommand "config --global --add user.email ddtu-1@outlook.com"
Invoke-GitCommand "config --global --add user.name 'DevDiv Tester 1'"

$newVSLogFile = "$dest\Logs\UpdateVS.log"
$newResultFile = "$dest\Logs\ExitCode.log"
Copy-Item $UpdateVSLogFile -Destination $newVSLogFile -Force
Copy-Item $ResultFile -Destination $newResultFile -Force

Invoke-GitCommand "add $newVSLogFile $newResultFile"
Invoke-GitCommand "commit -m `"Updating logs from VS Upgrade`""
Invoke-GitCommand "push origin main"

if ($exitCode -eq 3010) {
    Restart-Computer -Force
}
