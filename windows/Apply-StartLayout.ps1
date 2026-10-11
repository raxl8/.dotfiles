#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^S-1-[0-9-]+$')][string]$ExpectedUserSid,
    [Parameter(Mandatory)][string]$LayoutPath,
    [Parameter(Mandatory)][string]$BackupDirectory
)
$ErrorActionPreference = 'Stop'
try {
    if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne $ExpectedUserSid) {
        throw 'Approve Start layout as the same Windows user; another administrator would configure the wrong account.'
    }
    Import-Module (Join-Path $PSScriptRoot 'Modules\Dotfiles.Windows.psm1') -Force
    if (-not (Test-SetupAdministrator)) { throw 'The Start-layout policy helper requires elevation.' }
    Set-DotfilesStartLayout -LayoutPath $LayoutPath -Info (Get-WindowsSetupInfo) -BackupDirectory $BackupDirectory
    exit 0
} catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
}
