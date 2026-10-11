#Requires -Version 5.1
<#
.SYNOPSIS
    Apply ReviOS and personal setup, continuing automatically after required reboots.
.EXAMPLE
    .\setup.ps1 -WhatIf
.EXAMPLE
    .\setup.ps1 -Stage Machine -InstallWSL
.EXAMPLE
    .\setup.ps1 -Stage User -InstallWSL
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('All', 'ReviOS', 'User', 'Machine')][string]$Stage = 'All',
    [string]$ReviOSPlaybook,
    [switch]$InteractiveReviOS,
    [switch]$InstallWSL,
    [switch]$ApplyStartLayout,
    [switch]$SkipPackages,
    [switch]$SkipEverydayApps,
    [switch]$IncludeGamingTools,
    [switch]$SkipFont,
    [switch]$SkipTerminal,
    [switch]$SkipPreferences,
    [switch]$SkipReviOS,
    [switch]$NoRestart,
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9._-]*$')][string]$DistroName = 'NixOS',
    [string]$WSLLocation = (Join-Path $env:LOCALAPPDATA 'WSL\NixOS')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'windows\Modules\Dotfiles.Windows.psm1') -Force
$configRoot = Join-Path $PSScriptRoot 'windows\config'
# Forward WhatIf explicitly: modules can inherit an invoking script's preferences.
try {
    if ($Stage -eq 'All') {
        if ($InteractiveReviOS) { throw 'Use -Stage ReviOS -InteractiveReviOS for the optional wizard.' }
        $automatic = @{}
        foreach ($entry in $PSBoundParameters.GetEnumerator()) {
            if ($entry.Key -ne 'Stage' -and $entry.Key -ne 'InteractiveReviOS') { $automatic[$entry.Key] = $entry.Value }
        }
        & (Join-Path $PSScriptRoot 'windows\Install-Windows.ps1') @automatic
        exit $LASTEXITCODE
    }
    if ($SkipReviOS -or $NoRestart) { throw '-SkipReviOS and -NoRestart belong to the automatic All stage.' }
    $dependencies = Import-PowerShellDataFile (Join-Path $configRoot 'dependencies.psd1')
    $windows = Get-WindowsSetupInfo
    Assert-WindowsSetupSupport -Info $windows -InstallWSL:$InstallWSL
    Write-Host "Windows $($windows.DisplayVersion) (build $($windows.Build)), stage: $Stage"
    if ($Stage -eq 'ReviOS') {
        if ($InstallWSL -or $ApplyStartLayout -or $SkipPackages -or $SkipEverydayApps -or $IncludeGamingTools -or $SkipFont -or $SkipTerminal -or $SkipPreferences) {
            throw 'Personal setup switches belong to -Stage User or -Stage Machine. ReviOS setup runs first.'
        }
        if ($InteractiveReviOS) {
            Start-DotfilesReviOS -PlaybookPath $ReviOSPlaybook -Dependency $dependencies.ReviOS -WizardDependency $dependencies.AME -WhatIf:$WhatIfPreference
        } else {
            $result = Install-DotfilesReviOS -PlaybookPath $ReviOSPlaybook -Dependency $dependencies.ReviOS -CLIDependency $dependencies.AMECLI -OptionsPath (Join-Path $configRoot 'revios-options.json') -WhatIf:$WhatIfPreference
            if ($result -eq 'PreparationRestart') {
                Write-Host 'AME preparation staged. Restart Windows and rerun this ReviOS command with the same options. The playbook has not been applied yet.'
                exit 3010
            }
            if ($result -eq 'AppliedRestart') {
                Write-Host 'ReviOS applied. Restart Windows to finalize its packages, then run .\setup.ps1 -Stage User for your apps and settings.'
                exit 3010
            }
        }
        exit 0
    }
    if ($InteractiveReviOS) { throw '-InteractiveReviOS belongs to the ReviOS stage.' }
    if ($Stage -eq 'Machine') {
        if (-not $InstallWSL) {
            Write-Host 'No machine changes requested. WSL is opt-in with -InstallWSL.'
            exit 0
        }
        if (-not $WhatIfPreference -and -not (Test-SetupAdministrator)) {
            throw 'Run the Machine stage in an elevated PowerShell window.'
        }
        $restartRequired = Enable-DotfilesWSL -WhatIf:$WhatIfPreference
        if ($restartRequired) {
            Write-Host 'Restart Windows, then rerun the Machine stage before running the User stage with -InstallWSL.'
            exit 3010
        }
        if ($WhatIfPreference) { Write-Host 'WSL preparation preview complete. No changes were applied.' }
        else { Write-Host 'WSL prepared. Run .\setup.ps1 -Stage User -InstallWSL as your normal Windows user.' }
        exit 0
    }
    if (Test-SetupAdministrator) {
        Write-Warning 'User stage is elevated. Use your normal Windows account; do not run as a different administrator.'
    }
    if (-not $SkipPackages) {
        $restartRequired = Install-DotfilesPackages -ManifestPath (Join-Path $configRoot 'essentials.json') -WhatIf:$WhatIfPreference
        if ($restartRequired) {
            Write-Host 'A package requires a restart. Restart Windows, then rerun this command with the same options.'
            exit 3010
        }
    }
    if ($PSVersionTable.PSVersion.Major -lt 7 -and -not $WhatIfPreference) {
        # WinGet works in Windows PowerShell; install prerequisites before requiring pwsh.
        $powerShell = Get-SetupPowerShell7
        exit (Invoke-DotfilesUserContinuation -PowerShellPath $powerShell -ScriptPath $PSCommandPath -Parameters $PSBoundParameters)
    }
    if ($InstallWSL -and -not $WhatIfPreference) { Assert-WSLVersion }
    $backupDirectory = Join-Path (Join-Path $env:LOCALAPPDATA 'dotfiles\backups') ([guid]::NewGuid().ToString())
    if (-not $SkipPackages) {
        $manifests = @('packages.json')
        if (-not $SkipEverydayApps) { $manifests += 'everyday-apps.json' }
        if ($IncludeGamingTools) { $manifests += 'gaming-tools.json' }
        foreach ($manifest in $manifests) {
            if (Install-DotfilesPackages -ManifestPath (Join-Path $configRoot $manifest) -WhatIf:$WhatIfPreference) {
                Write-Host 'A package requires a restart. Restart Windows, then rerun this command with the same options.'
                exit 3010
            }
        }
    }
    if (-not $SkipFont) { Install-DotfilesFont -Dependency $dependencies.Font -WhatIf:$WhatIfPreference }
    if (-not $SkipTerminal) {
        Set-DotfilesTerminal -TemplatePath (Join-Path $configRoot 'terminal.json') -BackupDirectory $backupDirectory -WhatIf:$WhatIfPreference
    }
    if (-not $SkipPreferences) { Set-DotfilesPreferences -BackupDirectory $backupDirectory -WhatIf:$WhatIfPreference }
    if ($ApplyStartLayout) {
        Set-DotfilesStartLayout -LayoutPath (Join-Path $configRoot 'start-layout.json') -Info $windows -BackupDirectory $backupDirectory -WhatIf:$WhatIfPreference
    }
    if ($InstallWSL) {
        Install-DotfilesWSL -Dependency $dependencies.WSL -Name $DistroName -Location $WSLLocation -WhatIf:$WhatIfPreference
    }
    if ($WhatIfPreference) { Write-Host 'Preview complete. No setup changes were applied.' }
    else { Write-Host 'Setup complete. Sign out and back in to refresh shell preferences.' }
    if (Test-Path -LiteralPath $backupDirectory) { Write-Host "Settings backup: $backupDirectory" }
    exit 0
} catch {
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    exit 1
}
