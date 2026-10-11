#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$RunDirectory)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Modules\Dotfiles.Windows.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules\Dotfiles.Continuation.psm1') -Force
$transcribing = $false
try {
    Assert-DotfilesProtectedRun -Path $RunDirectory
    if (Test-SetupAdministrator) { throw 'Personal setup must run without elevation.' }
    $state = Get-Content -LiteralPath (Join-Path $RunDirectory 'state.json') -Raw | ConvertFrom-Json
    if ($state.UserSid -ne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value) { throw 'Personal setup account does not match.' }
    $options = @{}
    foreach ($property in $state.Options.PSObject.Properties) { $options[$property.Name] = $property.Value }
    $logDirectory = Join-Path $env:LOCALAPPDATA 'dotfiles\logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    Start-Transcript -Path (Join-Path $logDirectory ($state.TaskName + '-User.log')) -Append | Out-Null
    $transcribing = $true
    & (Join-Path (Split-Path $PSScriptRoot -Parent) 'setup.ps1') -Stage User @options
    exit $LASTEXITCODE
} catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
} finally {
    if ($transcribing) { Stop-Transcript | Out-Null }
}
