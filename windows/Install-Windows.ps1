#Requires -Version 5.1
<#
.SYNOPSIS
    Run ReviOS and personal setup, resuming automatically after required reboots.
.DESCRIPTION
    Start elevated as the same Windows account you will use. No passwords or
    automatic logon are configured. Sign in after each reboot to continue.
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'New')]
param(
    [Parameter(ParameterSetName = 'New')][string]$ReviOSPlaybook,
    [Parameter(ParameterSetName = 'New')][switch]$SkipReviOS,
    [Parameter(ParameterSetName = 'New')][switch]$InstallWSL,
    [Parameter(ParameterSetName = 'New')][switch]$ApplyStartLayout,
    [Parameter(ParameterSetName = 'New')][switch]$IncludeGamingTools,
    [Parameter(ParameterSetName = 'New')][switch]$SkipPackages,
    [Parameter(ParameterSetName = 'New')][switch]$SkipEverydayApps,
    [Parameter(ParameterSetName = 'New')][switch]$SkipFont,
    [Parameter(ParameterSetName = 'New')][switch]$SkipTerminal,
    [Parameter(ParameterSetName = 'New')][switch]$SkipPreferences,
    [Parameter(ParameterSetName = 'New')][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9._-]*$')][string]$DistroName = 'NixOS',
    [Parameter(ParameterSetName = 'New')][string]$WSLLocation = (Join-Path $env:LOCALAPPDATA 'WSL\NixOS'),
    [Parameter(ParameterSetName = 'New')][switch]$NoRestart,
    [Parameter(Mandatory, ParameterSetName = 'Resume')][switch]$Resume,
    [Parameter(Mandatory, ParameterSetName = 'Cancel')][switch]$Cancel,
    [Parameter(Mandatory, ParameterSetName = 'Resume')]
    [Parameter(Mandatory, ParameterSetName = 'Cancel')][string]$RunDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Modules\Dotfiles.Windows.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules\Dotfiles.Continuation.psm1') -Force
$transcribing = $false
$state = $null
$mutex = $null
$ownsMutex = $false
try {
    if ($WhatIfPreference) {
        [void]$PSCmdlet.ShouldProcess('Windows setup', 'Snapshot setup, register temporary logon continuation, apply ReviOS, restart when needed, install apps as the normal user, remove continuation')
        exit 0
    }
    if (-not (Test-SetupAdministrator)) { throw 'Start this command in elevated PowerShell as the same Windows account whose apps/settings you want.' }
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $mutex = New-Object Threading.Mutex($false, ('Global\DotfilesWindowsSetup-' + $sid))
    try { $ownsMutex = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
    if (-not $ownsMutex) { throw 'Another automatic setup is already running for this Windows account.' }
    $powerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if ($PSCmdlet.ParameterSetName -eq 'New') {
        Assert-WindowsSetupSupport -Info (Get-WindowsSetupInfo) -InstallWSL:$InstallWSL
        $dependencies = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'config\dependencies.psd1')
        if (-not $SkipReviOS) {
            $ReviOSPlaybook = Resolve-DotfilesReviOSPlaybook -Path $ReviOSPlaybook -Dependency $dependencies.ReviOS
        }
        $id = [guid]::NewGuid().ToString()
        $RunDirectory = Join-Path $env:ProgramFiles ('DotfilesSetup-' + $id)
        New-DotfilesProtectedRun -Path $RunDirectory
        $payload = Join-Path $RunDirectory 'repo'
        New-Item -ItemType Directory -Path (Join-Path $payload 'windows') | Out-Null
        Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'setup.ps1') -Destination $payload
        foreach ($name in @('Modules', 'config', 'Install-Windows.ps1', 'Run-UserSetup.ps1', 'Apply-StartLayout.ps1')) {
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $payload 'windows') -Recurse
        }
        if (-not $SkipReviOS) { Copy-Item -LiteralPath $ReviOSPlaybook -Destination (Join-Path $RunDirectory 'ReviOS.apbx') }
        $options = @{ InstallWSL = [bool]$InstallWSL }
        foreach ($name in @('InstallWSL','IncludeGamingTools','SkipPackages','SkipEverydayApps','SkipFont','SkipTerminal','SkipPreferences')) {
            if ((Get-Variable -Name $name -ValueOnly)) { $options[$name] = $true }
        }
        $options.DistroName = $DistroName
        $options.WSLLocation = $WSLLocation
        $state = @{ UserSid = $sid; TaskName = "DotfilesSetup-$id"; Phase = 'ReviOS'; Options = $options;
            SkipReviOS = [bool]$SkipReviOS; ApplyStartLayout = [bool]$ApplyStartLayout; NoRestart = [bool]$NoRestart;
            Restarts = 0; WaitingBoot = ''; Status = 'Running' }
        Save-DotfilesRunState -Directory $RunDirectory -State $state
    } else {
        Assert-DotfilesProtectedRun -Path $RunDirectory
        $state = Get-Content -LiteralPath (Join-Path $RunDirectory 'state.json') -Raw | ConvertFrom-Json
        if ($state.UserSid -ne $sid) { throw 'Resume or cancel using the original Windows account.' }
    }
    if ($Cancel) {
        Remove-DotfilesContinuation -TaskName $state.TaskName
        $state.Status = 'Cancelled'
        Save-DotfilesRunState -Directory $RunDirectory -State $state
        Write-Host "Continuation cancelled. Files and logs retained: $RunDirectory"
        exit 0
    }
    if ($state.Status -eq 'Completed') { Write-Host 'This setup run already completed.'; exit 0 }
    Start-Transcript -Path (Join-Path $RunDirectory 'installation.log') -Append | Out-Null
    $transcribing = $true
    Write-Host "Setup state and log: $RunDirectory"
    # Prefix the ISO value so ConvertFrom-Json does not turn it into DateTime.
    $boot = 'boot-' + (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
    $runner = Join-Path $RunDirectory 'repo\windows\Install-Windows.ps1'
    $action = New-ScheduledTaskAction -Execute $powerShell -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runner`" -Resume -RunDirectory `"$RunDirectory`""
    $principal = New-ScheduledTaskPrincipal -UserId $sid -LogonType Interactive -RunLevel Highest
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $sid
    $trigger.Delay = 'PT30S'
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 24) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $state.TaskName -Action $action -Principal $principal -Trigger $trigger -Settings $settings -Force | Out-Null
    if ($state.WaitingBoot -eq $boot) {
        $state.Status = 'RestartRequired'
        Save-DotfilesRunState -Directory $RunDirectory -State $state
        Write-Host 'Restart Windows and sign in to continue.'
        exit 3010
    }
    $state.WaitingBoot = ''
    $state.Status = 'Running'
    Save-DotfilesRunState -Directory $RunDirectory -State $state
    Import-Module (Join-Path $RunDirectory 'repo\windows\Modules\Dotfiles.Windows.psm1') -Force
    $config = Join-Path $RunDirectory 'repo\windows\config'
    $dependencies = Import-PowerShellDataFile (Join-Path $config 'dependencies.psd1')
    while ($state.Phase -ne 'Completed') {
        $restart = $false
        switch ($state.Phase) {
            'ReviOS' {
                if ($state.SkipReviOS) { $state.Phase = 'Machine'; break }
                $result = Install-DotfilesReviOS -PlaybookPath (Join-Path $RunDirectory 'ReviOS.apbx') -Dependency $dependencies.ReviOS -CLIDependency $dependencies.AMECLI -OptionsPath (Join-Path $config 'revios-options.json')
                $state.Phase = Get-DotfilesNextPhase -Phase 'ReviOS' -Result $result
                $restart = $true
            }
            'Machine' {
                if ($state.Options.InstallWSL) { $restart = Enable-DotfilesWSL }
                if (-not $restart) {
                    if ($state.ApplyStartLayout) {
                        Set-DotfilesStartLayout -LayoutPath (Join-Path $config 'start-layout.json') -Info (Get-WindowsSetupInfo) -BackupDirectory (Join-Path $env:LOCALAPPDATA "dotfiles\backups\$($state.TaskName)")
                    }
                    $state.Phase = 'User'
                }
            }
            'User' {
                $worker = Join-Path $RunDirectory 'repo\windows\Run-UserSetup.ps1'
                $userAction = New-ScheduledTaskAction -Execute $powerShell -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$worker`" -RunDirectory `"$RunDirectory`""
                $userPrincipal = New-ScheduledTaskPrincipal -UserId $sid -LogonType Interactive -RunLevel Limited
                $userTask = $state.TaskName + '-User'
                Register-ScheduledTask -TaskName $userTask -Action $userAction -Principal $userPrincipal -Settings $settings -Force | Out-Null
                $previous = (Get-ScheduledTaskInfo -TaskName $userTask).LastRunTime
                Start-ScheduledTask -TaskName $userTask
                $deadline = (Get-Date).AddHours(23)
                do {
                    Start-Sleep -Seconds 3
                    $info = Get-ScheduledTaskInfo -TaskName $userTask
                    $task = Get-ScheduledTask -TaskName $userTask
                    if ((Get-Date) -gt $deadline) { throw 'Personal setup timed out. Inspect its log.' }
                } while ($info.LastRunTime -eq $previous -or $task.State -in @('Running', 'Queued'))
                $state.Phase = Get-DotfilesNextPhase -Phase 'User' -Result ([string]$info.LastTaskResult)
                $restart = $info.LastTaskResult -eq 3010
            }
            default { throw "Unknown setup phase: $($state.Phase)" }
        }
        if ($restart) {
            $state.Restarts++
            if ($state.Restarts -gt 6) { throw 'Setup exceeded six restart boundaries; automatic continuation stopped.' }
            $state.WaitingBoot = $boot
            $state.Status = 'RestartRequired'
            Save-DotfilesRunState -Directory $RunDirectory -State $state
            Write-Host 'Setup will continue after restart and Windows sign-in. Apps can stay signed out.'
            if (-not $state.NoRestart) {
                Write-Host 'Restarting in 30 seconds. Save any open work.'
                & (Join-Path $env:SystemRoot 'System32\shutdown.exe') /r /t 30 /d p:2:4 /c 'Dotfiles setup: restart and sign in to continue.'
                if ($LASTEXITCODE -ne 0) { throw 'Could not schedule restart; restart manually to continue.' }
            }
            exit 3010
        }
        Save-DotfilesRunState -Directory $RunDirectory -State $state
    }
    $state.Status = 'Completed'
    Save-DotfilesRunState -Directory $RunDirectory -State $state
    Remove-DotfilesContinuation -TaskName $state.TaskName
    Write-Host 'Windows setup complete. Apps are ready for your own sign-in. Sign out/in to refresh shell settings.'
    exit 0
} catch {
    if ($state) {
        Remove-DotfilesContinuation -TaskName $state.TaskName
        $state.Status = 'Failed'
        Save-DotfilesRunState -Directory $RunDirectory -State $state
    }
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
} finally {
    if ($transcribing) { Stop-Transcript | Out-Null }
    if ($ownsMutex) { $mutex.ReleaseMutex() }
    if ($mutex) { $mutex.Dispose() }
}
