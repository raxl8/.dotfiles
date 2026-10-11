#Requires -Version 5.1
<#
.SYNOPSIS
    Restore the current user's registry preferences from one setup backup.
#>
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$BackupDirectory)
$ErrorActionPreference = 'Stop'
$entries = @(Import-Clixml -LiteralPath (Join-Path $BackupDirectory 'registry.clixml'))
# Validate the entire journal before writing any values.
$allowedPaths = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',
    'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
)
foreach ($entry in $entries) {
    if ($entry.Path -notin $allowedPaths -or $entry.Type -notin @('DWord', 'QWord', 'String', 'ExpandString', 'MultiString', 'Binary', 'None')) {
        throw 'Backup contains an unexpected registry path or type.'
    }
}
$layoutBackup = Join-Path $BackupDirectory 'start-layout.json'
if ((Test-Path -LiteralPath $layoutBackup) -and $PSCmdlet.ShouldProcess('Current user dotfiles Start layout', 'Restore layout file')) {
    Copy-Item -LiteralPath $layoutBackup -Destination (Join-Path $env:LOCALAPPDATA 'dotfiles\start-layout.json') -Force
}
foreach ($entry in $entries) {
    if ($PSCmdlet.ShouldProcess("$($entry.Path)\$($entry.Name)", 'Restore original preference')) {
        if ($entry.Exists) {
            if (-not (Test-Path -LiteralPath $entry.Path)) { New-Item -Path $entry.Path -Force | Out-Null }
            New-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -Value $entry.Value -PropertyType $entry.Type -Force | Out-Null
        } elseif (Test-Path -LiteralPath $entry.Path) {
            Remove-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
        }
    }
}
Write-Host 'Preference restore complete. Sign out and back in to refresh the shell.'
