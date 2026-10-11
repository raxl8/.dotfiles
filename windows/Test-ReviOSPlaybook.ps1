#Requires -Version 5.1
<#
.SYNOPSIS
    Verify a manually downloaded ReviOS playbook before loading it into AME Wizard.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$Path)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Modules\Dotfiles.Windows.psm1') -Force
$dependency = (Import-PowerShellDataFile (Join-Path $PSScriptRoot 'config\dependencies.psd1')).ReviOS
Assert-ReviOSPlaybook -Path $Path -Dependency $dependency
Write-Host "Verified ReviOS $($dependency.Version). Load this file into AME Wizard and review the options:"
(Resolve-Path -LiteralPath $Path).Path
