#Requires -Version 5.1
Set-StrictMode -Version Latest

function Get-WindowsSetupInfo {
    if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitProcess) {
        throw 'Use 64-bit PowerShell on Windows 11.'
    }
    $version = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    [pscustomobject]@{
        DisplayVersion = $version.DisplayVersion
        Build = [int]$version.CurrentBuildNumber
        Revision = [int]$version.UBR
        Edition = $version.EditionID
        Architecture = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE')
    }
}

function Assert-WindowsSetupSupport {
    param([Parameter(Mandatory)]$Info, [switch]$InstallWSL)
    if ($Info.Build -lt 26100) { throw 'Windows 11 24H2 or later is required. Install Windows updates first.' }
    if ($InstallWSL -and $Info.Architecture -ne 'AMD64') {
        throw 'The optional NixOS image and #wsl flake target are x64-only. The native Windows setup also supports ARM64.'
    }
    if ($Info.DisplayVersion -notin @('24H2', '25H2', '26H1', '26H2')) {
        Write-Warning "Unvalidated Windows release: $($Info.DisplayVersion). Preview with -WhatIf."
    }
}

function Test-SetupAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-ReviOSPlaybook {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][hashtable]$Dependency)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Download ReviOS $($Dependency.Version) from https://revi.cc/download first. Pass -ReviOSPlaybook '<path to .apbx>' or save it to $Path."
    }
    if ([IO.Path]::GetExtension($Path) -ne '.apbx') { throw 'Expected a ReviOS .apbx playbook.' }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Dependency.SHA256) {
        throw "Playbook does not match pinned ReviOS $($Dependency.Version). Check $($Dependency.ReleaseUrl); do not load this file."
    }
}

function Start-DotfilesReviOS {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$PlaybookPath,
          [Parameter(Mandatory)][hashtable]$Dependency,
          [Parameter(Mandatory)][hashtable]$WizardDependency)
    $info = Get-WindowsSetupInfo
    if ($info.Build -notin $Dependency.Builds) { throw "ReviOS $($Dependency.Version) does not declare support for build $($info.Build)." }
    if ($WhatIfPreference) {
        [void]$PSCmdlet.ShouldProcess("ReviOS $($Dependency.Version)", 'Verify playbook, download verified AME Wizard, launch interactive installation')
        return
    }
    Assert-ReviOSPlaybook -Path $PlaybookPath -Dependency $Dependency
    if ($PSCmdlet.ShouldProcess("ReviOS $($Dependency.Version)", 'Launch AME Wizard for interactive installation')) {
        # Keep downloads out of TEMP: an optimization playbook may empty it or reboot.
        $directory = Join-Path $env:LOCALAPPDATA 'dotfiles\installers'
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        $wizard = Join-Path $directory 'AME-Beta-v0.8.4.exe'
        if (-not (Test-Path -LiteralPath $wizard) -or (Get-FileHash -LiteralPath $wizard).Hash -ne $WizardDependency.SHA256) {
            Save-VerifiedSetupDownload -Url $WizardDependency.Url -SHA256 $WizardDependency.SHA256 -Destination $wizard
        }
        Write-Host ('Load this verified playbook into AME Wizard: ' + (Resolve-Path -LiteralPath $PlaybookPath).Path)
        Write-Host 'Select Enable Defender and review your removal/hibernate options. Complete AME, including any requested reboot.'
        Start-Process -FilePath $wizard -Verb RunAs -Wait -ErrorAction Stop
        # Closing the GUI is not proof that the user applied a playbook successfully.
        Write-Host 'After AME reports success and you restart, run .\setup.ps1 -Stage User to install your apps and settings. WSL stays opt-in.'
    }
}

function Assert-ReviOSAutomaticRequirements {
    [CmdletBinding()]
    param()
    if (-not (Test-SetupAdministrator)) { throw 'Run the automatic ReviOS stage in an elevated PowerShell window.' }
    $status = Get-MpComputerStatus -ErrorAction Stop
    if ($status.IsTamperProtected) {
        throw 'Windows Tamper Protection is enabled. AME requires it off before ReviOS can run. Turn it off in Windows Security, then rerun setup. Scripts cannot change this protected setting.'
    }
    foreach ($key in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )) {
        if (Test-Path -LiteralPath $key) { throw 'Windows has pending updates or a pending restart. Finish Windows Update and restart before ReviOS.' }
    }
    $antivirus = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop |
        Where-Object { $_.displayName -notmatch '^(Microsoft|Windows) Defender' })
    if ($antivirus.Count) { throw 'AME requires third-party antivirus removed before applying this playbook.' }
    $batteries = @(Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop)
    if (@($batteries | Where-Object { $_.BatteryStatus -eq 1 }).Count) { throw 'Connect AC power before applying ReviOS.' }
}

function Expand-ReviOSCLIPlaybook {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$CLIDirectory, [Parameter(Mandatory)][string]$PlaybookPath,
          [Parameter(Mandatory)][string]$Destination, [Parameter(Mandatory)][hashtable]$Dependency,
          [Parameter(Mandatory)][string[]]$Options)
    # The verified vendor CLI includes its own 7-Zip; no extra installed utility.
    $assembly = [Reflection.Assembly]::LoadFrom((Join-Path $CLIDirectory 'TrustedUninstaller.CLI.exe'))
    $resource = 'TrustedUninstaller.CLI.Properties.resources.7za.exe'
    $source = $assembly.GetManifestResourceStream($resource)
    if ($null -eq $source) { throw 'Verified AME CLI does not contain the expected extractor.' }
    $extractor = Join-Path $CLIDirectory '7za.exe'
    try {
        $target = [IO.File]::Create($extractor)
        try { $source.CopyTo($target) } finally { $target.Dispose() }
    } finally { $source.Dispose() }
    [void](Invoke-SetupNative -FilePath $extractor -ArgumentList @('x', '-y', '-pmalte', $PlaybookPath, "-o$Destination"))
    [xml]$config = Get-Content (Join-Path $Destination 'playbook.conf') -Raw
    if ($config.Playbook.Name -ne 'ReviOS' -or $config.Playbook.Version -ne $Dependency.Version) { throw 'Extracted playbook identity/version differs from the pinned release.' }
    $available = @($config.SelectNodes('/Playbook/FeaturePages/*/Options/*/Name') | ForEach-Object { $_.InnerText })
    $unknown = @($Options | Where-Object { $_ -notin $available })
    if ($unknown.Count) { throw "Unknown playbook options: $($unknown -join ', ')" }
    if ('enable-defender' -notin $Options -or 'disable-defender' -in $Options) { throw 'This automatic profile must enable Defender.' }
}

function Initialize-ReviOSUCPD {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$BackupDirectory)
    $driver = Get-CimInstance -ClassName Win32_SystemDriver -Filter "Name='UCPD'" -ErrorAction Stop
    if ($null -eq $driver -or $driver.State -ne 'Running') { return $false }
    # The pinned ReviOS services task disables UCPD. Stage that change before the
    # playbook so its widget policy writes do not encounter the still-loaded driver.
    $task = Get-ScheduledTask -TaskPath '\Microsoft\Windows\AppxDeploymentClient\' -TaskName 'UCPD velocity' -ErrorAction SilentlyContinue
    if (-not $PSCmdlet.ShouldProcess('ReviOS UCPD prerequisite', 'Stage the pinned playbook driver/task changes; require restart before applying ReviOS')) { return $false }
    New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    @{ DriverStartMode = $driver.StartMode; TaskPresent = ($null -ne $task); TaskState = $(if ($task) { [string]$task.State } else { $null }) } |
        ConvertTo-Json | Set-Content (Join-Path $BackupDirectory 'ucpd-preparation-backup.json') -Encoding UTF8
    if ($driver.StartMode -ne 'Disabled') {
        [void](Invoke-SetupNative -FilePath 'sc.exe' -ArgumentList @('config', 'UCPD', 'start=', 'disabled'))
    }
    if ($task -and $task.State -ne 'Disabled') {
        Disable-ScheduledTask -TaskPath '\Microsoft\Windows\AppxDeploymentClient\' -TaskName 'UCPD velocity' -ErrorAction Stop | Out-Null
    }
    $staged = Get-CimInstance -ClassName Win32_SystemDriver -Filter "Name='UCPD'" -ErrorAction Stop
    if ($staged.StartMode -ne 'Disabled') { throw 'The ReviOS UCPD prerequisite did not accept its disabled startup setting.' }
    # A loaded UCPD cannot be unloaded here. Do not continue or ignore write errors.
    return $true
}

function Invoke-ReviOSCLI {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$CLIDirectory, [Parameter(Mandatory)][string]$PlaybookDirectory,
          [Parameter(Mandatory)][string[]]$Options, [Parameter(Mandatory)][string]$LogPath)
    $PSNativeCommandUseErrorActionPreference = $false
    Push-Location -LiteralPath $CLIDirectory
    try {
        # Use the vendor's own readiness check so it cannot fall into Console.ReadKey.
        $assembly = [Reflection.Assembly]::LoadFrom((Join-Path $CLIDirectory 'TrustedUninstaller.CLI.exe'))
        $method = $assembly.GetType('TrustedUninstaller.CLI.CLI').GetMethod('GetDefenderToggles')
        $task = $method.Invoke($null, @())
        $toggles = $task.GetAwaiter().GetResult()
        if (@($toggles | Where-Object { $_ }).Count) { throw 'AME still reports an enabled protection toggle. No CLI was launched.' }
        # Preserve argument boundaries; do not construct a shell command.
        & (Join-Path $CLIDirectory 'TrustedUninstaller.CLI.exe') $PlaybookDirectory @Options 2>&1 |
            Tee-Object -FilePath $LogPath | Out-Host
        $code = $LASTEXITCODE
        Assert-ReviOSCompletion -ExitCode $code -LogPath $LogPath
    } finally { Pop-Location }
}

function Assert-ReviOSCompletion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$ExitCode, [Parameter(Mandatory)][string]$LogPath)
    $text = Get-Content -LiteralPath $LogPath -Raw
    if ($ExitCode -ne 0 -or $text -notmatch '(?m)^Playbook completed successfully\.\s*$' -or
        $text -match 'Playbook completed with errors\.|Fatal Playbook Error|YAML Error:') {
        throw "ReviOS did not complete successfully (CLI exit $ExitCode). Inspect $LogPath before continuing."
    }
    $packages = @(Get-WindowsPackage -Online -ErrorAction Stop |
        Where-Object { $_.PackageName -like '*ReviOS*' -and $_.PackageState -in @('Installed', 'InstallPending') })
    if (-not $packages.Count) { throw "CLI reported success but no installed or restart-pending ReviOS packages were found. Inspect $LogPath." }
}

function Install-DotfilesReviOS {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$PlaybookPath, [Parameter(Mandatory)][hashtable]$Dependency,
          [Parameter(Mandatory)][hashtable]$CLIDependency, [Parameter(Mandatory)][string]$OptionsPath)
    $info = Get-WindowsSetupInfo
    if ($info.Build -notin $Dependency.Builds) { throw "ReviOS $($Dependency.Version) does not declare support for build $($info.Build)." }
    if ($info.Architecture -ne 'AMD64') { throw 'The automatic ReviOS CLI workflow is validated on x64 Windows only.' }
    if ($WhatIfPreference) {
        [void]$PSCmdlet.ShouldProcess("ReviOS $($Dependency.Version)", 'Verify dependencies and requirements, apply pinned playbook automatically with Defender enabled, verify installed packages')
        return $false
    }
    Assert-ReviOSPlaybook -Path $PlaybookPath -Dependency $Dependency
    Assert-ReviOSAutomaticRequirements
    if (-not $PSCmdlet.ShouldProcess("ReviOS $($Dependency.Version)", 'Apply verified playbook automatically with Defender enabled')) { return $false }
    $options = Get-ReviOSOptions -Path $OptionsPath
    $directory = Join-Path (Join-Path $env:LOCALAPPDATA 'dotfiles\installers') ('revios-' + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    if (Initialize-ReviOSUCPD -BackupDirectory $directory -WhatIf:$WhatIfPreference) { return 'PreparationRestart' }
    $archive = Join-Path $directory 'CLI-Standalone.zip'
    Save-VerifiedSetupDownload -Url $CLIDependency.Url -SHA256 $CLIDependency.SHA256 -Destination $archive
    $cli = Join-Path $directory 'cli'
    Expand-Archive -LiteralPath $archive -DestinationPath $cli
    $playbook = Join-Path $directory 'playbook'
    Expand-ReviOSCLIPlaybook -CLIDirectory $cli -PlaybookPath (Resolve-Path -LiteralPath $PlaybookPath).Path -Destination $playbook -Dependency $Dependency -Options $options
    $log = Join-Path $directory 'installation.log'
    # Keep recovery information outside TEMP; retain it on success and failure.
    $preferences = Get-MpPreference -ErrorAction Stop
    $restore = @{
        DisableRealtimeMonitoring = [bool]$preferences.DisableRealtimeMonitoring
        MAPSReporting = [int]$preferences.MAPSReporting
        SubmitSamplesConsent = [int]$preferences.SubmitSamplesConsent
    }
    $restore | ConvertTo-Json | Set-Content (Join-Path $directory 'defender-preparation-backup.json') -Encoding UTF8
    Write-Host "ReviOS log: $log"
    try {
        Set-MpPreference -DisableRealtimeMonitoring $true -MAPSReporting 0 -SubmitSamplesConsent 2 -ErrorAction Stop
        $accepted = $false
        for ($attempt = 0; $attempt -lt 10; $attempt++) {
            $prepared = Get-MpPreference -ErrorAction Stop
            if (-not (Get-MpComputerStatus -ErrorAction Stop).RealTimeProtectionEnabled -and $prepared.DisableRealtimeMonitoring -and
                [int]$prepared.MAPSReporting -eq 0 -and [int]$prepared.SubmitSamplesConsent -eq 2) {
                $accepted = $true
                break
            }
            Start-Sleep -Seconds 2
        }
        if (-not $accepted) {
            throw 'Windows did not accept the AME preparation settings. No playbook was launched.'
        }
        Invoke-ReviOSCLI -CLIDirectory $cli -PlaybookDirectory $playbook -Options $options -LogPath $log
    } finally {
        # The playbook profile enables Defender; restore temporary preparation preferences too.
        # A killed process/power loss may require recovery from the saved JSON.
        Set-MpPreference @restore -ErrorAction Stop
    }
    return 'AppliedRestart'
}

function Get-ReviOSOptions {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    # PS 5.1 emits a JSON array as one pipeline object; enumerate after assignment.
    $raw = Get-Content -LiteralPath $Path -Raw
    if ($raw -notmatch '^\s*\[') { throw 'ReviOS options must be a nonempty JSON array.' }
    $parsed = $raw | ConvertFrom-Json
    if (@($parsed).Count -eq 0) { throw 'ReviOS options must be a nonempty JSON array.' }
    foreach ($option in $parsed) {
        if ($option -isnot [string] -or $option -notmatch '^[a-z][a-z0-9-]+$') { throw 'ReviOS options must contain option names only.' }
        $option
    }
}

function Invoke-SetupNative {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FilePath,
          [Parameter(Mandatory)][string[]]$ArgumentList, [int[]]$SuccessCodes = @(0))
    $PSNativeCommandUseErrorActionPreference = $false
    # Preserve arguments instead of constructing a shell command string.
    & $FilePath @ArgumentList | Out-Host
    $code = $LASTEXITCODE
    if ($code -notin $SuccessCodes) {
        throw "$FilePath failed (exit code $code). Arguments: $($ArgumentList -join ' ')"
    }
    return $code
}

function Get-SetupPowerShell7 {
    # Use installed locations/persistent PATH, not a runtime injected into this process.
    $candidates = @((Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'))
    foreach ($package in @(Get-AppxPackage -Name 'Microsoft.PowerShell' -ErrorAction SilentlyContinue)) {
        $candidates += Join-Path $package.InstallLocation 'pwsh.exe'
    }
    foreach ($scope in @('Machine', 'User')) {
        foreach ($directory in ([Environment]::GetEnvironmentVariable('Path', $scope) -split ';')) {
            if (-not [string]::IsNullOrWhiteSpace($directory)) {
                $candidates += Join-Path ([Environment]::ExpandEnvironmentVariables($directory.Trim('"'))) 'pwsh.exe'
            }
        }
    }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $version = (Get-Item -LiteralPath $candidate).VersionInfo.ProductVersion
            if ($version -match '^7\.') { return $candidate }
        }
    }
    throw 'PowerShell 7 was not found in installed locations. Install Microsoft.PowerShell with WinGet, then rerun setup. -SkipPackages requires existing prerequisites.'
}

function Invoke-DotfilesUserContinuation {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PowerShellPath,
          [Parameter(Mandatory)][string]$ScriptPath,
          [Parameter(Mandatory)][System.Collections.IDictionary]$Parameters)
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath, '-Stage', 'User')
    foreach ($name in @('InstallWSL', 'ApplyStartLayout', 'SkipPackages', 'SkipEverydayApps', 'IncludeGamingTools', 'SkipFont', 'SkipTerminal', 'SkipPreferences')) {
        if ($Parameters.Keys -contains $name -and $Parameters[$name]) { $arguments += '-' + $name }
    }
    foreach ($name in @('DistroName', 'WSLLocation')) {
        if ($Parameters.Keys -contains $name) { $arguments += @("-$name", [string]$Parameters[$name]) }
    }
    Write-Host 'Continuing personal setup in installed PowerShell 7.'
    Invoke-SetupNative -FilePath $PowerShellPath -ArgumentList $arguments -SuccessCodes @(0, 1, 3010)
}

function Save-VerifiedSetupDownload {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Url,
          [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$SHA256,
          [Parameter(Mandatory)][string]$Destination)
    if (([uri]$Url).Scheme -ne 'https') { throw 'Downloads require HTTPS.' }
    $previousProgress = $ProgressPreference
    try {
        $ProgressPreference = 'SilentlyContinue'
        # Windows PowerShell 5.1 needs TLS 1.2 for GitHub.
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -ne $SHA256) {
            throw "SHA256 mismatch for $Url. The downloaded file will not be used."
        }
    } catch {
        if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Force }
        throw
    } finally { $ProgressPreference = $previousProgress }
}

function New-SetupTemporaryDirectory {
    $path = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $path -ErrorAction Stop | Out-Null
    return $path
}

function Remove-SetupTemporaryDirectory {
    param([Parameter(Mandatory)][string]$Path)
    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $parent = [IO.Path]::GetDirectoryName($fullPath)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    if ($parent -ne $tempRoot -or [IO.Path]::GetFileName($fullPath) -notmatch '^dotfiles-[0-9a-f-]{36}$') {
        throw "Refusing to remove unexpected temporary directory: $fullPath"
    }
    if (Test-Path -LiteralPath $fullPath) { Remove-Item -LiteralPath $fullPath -Recurse -Force }
}

function Install-DotfilesPackages {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$ManifestPath)
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    $restart = $false
    foreach ($source in $manifest.Sources) {
        foreach ($package in $source.Packages) {
            $id = $package.PackageIdentifier
            if ($PSCmdlet.ShouldProcess($id, 'Install using WinGet (keep already installed versions)')) {
                if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
                    throw 'WinGet is missing. Install/update App Installer from Microsoft Store, then open a new terminal.'
                }
                $arguments = @(
                    'install', '--id', $id, '--exact', '--source', $source.SourceDetails.Name,
                    '--no-upgrade', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
                )
                # Prefer the MSI installation so the bootstrap has a stable pwsh path.
                if ($id -eq 'Microsoft.PowerShell') { $arguments += @('--installer-type', 'wix') }
                $code = Invoke-SetupNative -FilePath 'winget.exe' -ArgumentList $arguments -SuccessCodes @(0, 3010, -1978335189, -1978335135, -1978334967, -1978334966, -1978334965)
                # WinGet: UPDATE_NOT_APPLICABLE (0x8A15002B), PACKAGE_ALREADY_INSTALLED (0x8A150061).
                # WinGet wraps installer reboot results in its own HRESULTs.
                if ($code -in @(3010, -1978334967, -1978334966, -1978334965)) { $restart = $true; break }
            }
        }
        if ($restart) { break }
    }
    return $restart
}

function Install-DotfilesFont {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][hashtable]$Dependency)
    if (-not $PSCmdlet.ShouldProcess('Current user fonts', 'Install JetBrains Mono Nerd Font')) { return }
    $tempDirectory = New-SetupTemporaryDirectory
    try {
        $zip = Join-Path $tempDirectory 'font.zip'
        Save-VerifiedSetupDownload -Url $Dependency.Url -SHA256 $Dependency.SHA256 -Destination $zip
        $extracted = Join-Path $tempDirectory 'font'
        Expand-Archive -LiteralPath $zip -DestinationPath $extracted
        $fonts = @(Get-ChildItem -LiteralPath $extracted -Filter 'JetBrainsMonoNerdFont-*.ttf' -File -Recurse)
        if ($fonts.Count -eq 0) { throw 'Font archive contains no expected TTF files.' }
        $fontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        $fontKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        New-Item -ItemType Directory -Path $fontDirectory -Force | Out-Null
        if (-not (Test-Path -LiteralPath $fontKey)) { New-Item -Path $fontKey -Force | Out-Null }
        foreach ($font in $fonts) {
            $destination = Join-Path $fontDirectory $font.Name
            if (-not (Test-Path -LiteralPath $destination) -or
                (Get-FileHash -LiteralPath $destination).Hash -ne (Get-FileHash -LiteralPath $font.FullName).Hash) {
                Copy-Item -LiteralPath $font.FullName -Destination $destination -Force
            }
            New-ItemProperty -LiteralPath $fontKey -Name ($font.BaseName + ' (TrueType)') -PropertyType String -Value $destination -Force | Out-Null
        }
        if (-not ('Dotfiles.FontNotification' -as [type])) {
            Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace Dotfiles {
    public static class FontNotification {
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg,
            UIntPtr wParam, IntPtr lParam, uint flags, uint timeout, out UIntPtr result);
    }
}
'@
        }
        $result = [UIntPtr]::Zero
        [Dotfiles.FontNotification]::SendMessageTimeout([IntPtr]0xffff, 0x001d, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$result) | Out-Null
    } finally { Remove-SetupTemporaryDirectory -Path $tempDirectory }
}

function Merge-SetupObject {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Current,
          [Parameter(Mandatory)][System.Collections.IDictionary]$Template)
    foreach ($key in @($Template.Keys)) {
        $value = $Template[$key]
        if ($value -is [System.Collections.IDictionary]) {
            if (-not $Current.Contains($key) -or $Current[$key] -isnot [System.Collections.IDictionary]) {
                $Current[$key] = [ordered]@{}
            }
            Merge-SetupObject -Current $Current[$key] -Template $value
        } elseif ($value -is [array] -and $key -in @('list', 'schemes', 'themes', 'actions', 'keybindings')) {
            $items = @()
            if ($Current.Contains($key)) { $items = @($Current[$key]) }
            foreach ($entry in $value) {
                $identityKey = switch ($key) {
                    'list' { 'guid' }
                    'actions' { 'id' }
                    'keybindings' { 'keys' }
                    default { 'name' }
                }
                $match = -1
                for ($i = 0; $i -lt $items.Count; $i++) {
                    if ($items[$i].Contains($identityKey) -and $entry.Contains($identityKey) -and $items[$i][$identityKey] -eq $entry[$identityKey]) {
                        $match = $i; break
                    }
                }
                if ($match -ge 0) { Merge-SetupObject -Current $items[$match] -Template $entry }
                else {
                    $newEntry = [ordered]@{}
                    Merge-SetupObject -Current $newEntry -Template $entry
                    $items += $newEntry
                }
            }
            $Current[$key] = $items
        } else { $Current[$key] = $value }
    }
}

function Set-DotfilesTerminal {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$TemplatePath,
          [Parameter(Mandatory)][string]$BackupDirectory)
    if ($WhatIfPreference) {
        [void]$PSCmdlet.ShouldProcess('Current user Windows Terminal settings', 'Merge template and back up settings')
        return
    }
    # PowerShell 7's JSON parser handles Terminal's comments and trailing commas.
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        if ($WhatIfPreference) { [void]$PSCmdlet.ShouldProcess('Current user Windows Terminal settings', 'Merge template and back up settings'); return }
        throw 'Terminal setup requires PowerShell 7 to preserve JSONC settings. Rerun with pwsh, or use -SkipTerminal on the first pass.'
    }
    $terminal = Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction Stop | Select-Object -First 1
    if ($null -eq $terminal) {
        if ($WhatIfPreference) { [void]$PSCmdlet.ShouldProcess('Current user Windows Terminal settings', 'Merge template and back up settings'); return }
        throw 'Windows Terminal is not registered for this user. Install it, launch it once, then rerun setup.'
    }
    $directory = Join-Path $env:LOCALAPPDATA ("Packages\$($terminal.PackageFamilyName)\LocalState")
    $path = Join-Path $directory 'settings.json'
    $current = [ordered]@{}
    if (Test-Path -LiteralPath $path) { $current = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable }
    $template = Get-Content -LiteralPath $TemplatePath -Raw | ConvertFrom-Json -AsHashtable
    Merge-SetupObject -Current $current -Template $template
    $content = $current | ConvertTo-Json -Depth 100
    if ((Test-Path -LiteralPath $path) -and (Get-Content -LiteralPath $path -Raw).Trim() -eq $content.Trim()) { return }
    if ($PSCmdlet.ShouldProcess($path, 'Back up and merge Windows Terminal settings')) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
        if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination (Join-Path $BackupDirectory 'terminal-settings.json') }
        $temporary = Join-Path $directory ('settings-' + [guid]::NewGuid() + '.tmp')
        try {
            [IO.File]::WriteAllText($temporary, $content, (New-Object Text.UTF8Encoding($false)))
            Move-Item -LiteralPath $temporary -Destination $path -Force
        } finally {
            if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
        }
    }
}

function Set-SetupRegistryValue {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name,
          [Parameter(Mandatory)]$Value, [ValidateSet('DWord', 'String')][string]$Type = 'DWord',
          [Parameter(Mandatory)][string]$BackupDirectory)
    $key = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    $exists = $null -ne $key -and $key.GetValueNames() -contains $Name
    if ($exists -and $key.GetValue($Name) -eq $Value -and $key.GetValueKind($Name).ToString() -eq $Type) { return }
    if ($PSCmdlet.ShouldProcess("$Path\$Name", "Set $Type value to $Value")) {
        New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
        $backupPath = Join-Path $BackupDirectory 'registry.clixml'
        $entries = @()
        if (Test-Path -LiteralPath $backupPath) { $entries = @(Import-Clixml -LiteralPath $backupPath) }
        if (-not ($entries | Where-Object { $_.Path -eq $Path -and $_.Name -eq $Name })) {
            $entries += [pscustomobject]@{
                Path = $Path; Name = $Name; Exists = $exists
                Value = $(if ($exists) { $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } else { $null })
                Type = $(if ($exists) { $key.GetValueKind($Name).ToString() } else { $Type })
            }
            $entries | Export-Clixml -LiteralPath $backupPath
        }
        if ($null -eq $key) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
    }
}

function Set-DotfilesPreferences {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$BackupDirectory)
    $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-SetupRegistryValue -Path $advanced -Name 'TaskbarAl' -Value 1 -BackupDirectory $BackupDirectory -WhatIf:$WhatIfPreference
    Set-SetupRegistryValue -Path $advanced -Name 'HideFileExt' -Value 0 -BackupDirectory $BackupDirectory -WhatIf:$WhatIfPreference
    Set-SetupRegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Value 0 -BackupDirectory $BackupDirectory -WhatIf:$WhatIfPreference
    $theme = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-SetupRegistryValue -Path $theme -Name 'AppsUseLightTheme' -Value 0 -BackupDirectory $BackupDirectory -WhatIf:$WhatIfPreference
    Set-SetupRegistryValue -Path $theme -Name 'SystemUsesLightTheme' -Value 0 -BackupDirectory $BackupDirectory -WhatIf:$WhatIfPreference
    Write-Host 'Choose Windows Terminal in Terminal Settings > Startup > Default terminal application.'
}

function Set-DotfilesStartLayout {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$LayoutPath, [Parameter(Mandatory)]$Info,
          [Parameter(Mandatory)][string]$BackupDirectory)
    if ($Info.Edition -notin @('Professional', 'ProfessionalN', 'ProfessionalEducation', 'ProfessionalWorkstation', 'Enterprise', 'EnterpriseN', 'Education', 'EducationN', 'IoTEnterprise', 'IoTEnterpriseS')) {
        throw 'Configure Start Pins requires a supported Pro, Enterprise, Education or IoT edition. Omit -ApplyStartLayout on Home.'
    }
    if ($Info.Build -eq 26100 -and $Info.Revision -lt 4770) {
        throw 'ApplyStartLayout requires KB5062660 (build 26100.4770) or later for applyOnce support.'
    }
    $layout = Get-Content -LiteralPath $LayoutPath -Raw | ConvertFrom-Json
    if (-not $layout.applyOnce) { throw 'Start layout must use applyOnce to preserve subsequent user changes.' }
    if (-not $WhatIfPreference -and -not (Test-SetupAdministrator)) {
        # HKCU Policies is protected on current Windows. Elevate only this opt-in
        # operation, while keeping package installation and personal setup unelevated.
        $helper = Join-Path (Split-Path $PSScriptRoot -Parent) 'Apply-StartLayout.ps1'
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $literalPaths = @($helper, [IO.Path]::GetFullPath($LayoutPath), [IO.Path]::GetFullPath($BackupDirectory)) |
            ForEach-Object { "'" + $_.Replace("'", "''") + "'" }
        $command = "& $($literalPaths[0]) -ExpectedUserSid '$sid' -LayoutPath $($literalPaths[1]) -BackupDirectory $($literalPaths[2]); exit `$LASTEXITCODE"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $powerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        Write-Host 'Approve the Start-layout policy prompt with this same Windows account.'
        $process = Start-Process -FilePath $powerShell -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded) -Wait -PassThru -ErrorAction Stop
        if ($process.ExitCode -ne 0) { throw "Start-layout policy application failed (exit $($process.ExitCode))." }
        return
    }
    $policy = Join-Path $env:LOCALAPPDATA 'dotfiles\start-layout.json'
    $content = $layout | ConvertTo-Json -Depth 20
    if ((-not (Test-Path -LiteralPath $policy) -or (Get-Content -LiteralPath $policy -Raw).Trim() -ne $content.Trim()) -and
        $PSCmdlet.ShouldProcess($policy, 'Save one-time Start layout')) {
        if (Test-Path -LiteralPath $policy) {
            New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
            Copy-Item -LiteralPath $policy -Destination (Join-Path $BackupDirectory 'start-layout.json')
        }
        New-Item -ItemType Directory -Path (Split-Path $policy -Parent) -Force | Out-Null
        $content | Set-Content -LiteralPath $policy -Encoding UTF8
    }
    # ADMX's documented ConfigureStartPins value points to the JSON file.
    Set-SetupRegistryValue -Path 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' -Name 'ConfigureStartPins' -Value $policy -Type String -BackupDirectory $BackupDirectory -WhatIf:$WhatIfPreference
}

function Enable-DotfilesWSL {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $restart = $false
    foreach ($name in @('VirtualMachinePlatform', 'Microsoft-Windows-Subsystem-Linux')) {
        if ($PSCmdlet.ShouldProcess($name, 'Enable optional Windows feature without restarting')) {
            $feature = Get-WindowsOptionalFeature -Online -FeatureName $name
            if ($feature.State -eq 'EnablePending') { $restart = $true }
            elseif ($feature.State -ne 'Enabled') {
                $result = Enable-WindowsOptionalFeature -Online -FeatureName $name -All -NoRestart
                $restart = $restart -or $result.RestartNeeded
            }
        }
    }
    if ($restart) { return $true }
    if ($PSCmdlet.ShouldProcess('WSL', 'Install/update WSL without a distribution')) {
        $code = Invoke-SetupNative -FilePath 'wsl.exe' -ArgumentList @('--install', '--no-distribution', '--no-launch') -SuccessCodes @(0, 3010)
        if ($code -eq 3010) { return $true }
        [void](Invoke-SetupNative -FilePath 'wsl.exe' -ArgumentList @('--update'))
    }
    return $false
}

function Assert-WSLVersion {
    $PSNativeCommandUseErrorActionPreference = $false
    $output = & wsl.exe --version
    if ($LASTEXITCODE -ne 0) { throw 'Prepare WSL first: run .\setup.ps1 -Stage Machine -InstallWSL as administrator.' }
    # WSL emits UTF-16 when redirected; native PowerShell capture can retain NULs.
    $versionText = ($output -join "`n") -replace "`0", ''
    $match = [regex]::Match($versionText, '\d+\.\d+\.\d+(?:\.\d+)?')
    if (-not $match.Success -or [version]$match.Value -lt [version]'2.4.4') {
        throw 'WSL 2.4.4 or later is required for .wsl files. Run the Machine stage to update WSL.'
    }
}

function Install-DotfilesWSL {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][hashtable]$Dependency,
          [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9._-]*$')][string]$Name,
          [Parameter(Mandatory)][string]$Location)
    $PSNativeCommandUseErrorActionPreference = $false
    if ($WhatIfPreference) { [void]$PSCmdlet.ShouldProcess($Name, "Install NixOS-WSL at $Location if absent"); return }
    Assert-WSLVersion
    $installed = & wsl.exe --list --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Could not list WSL distributions. Restart after preparing WSL and try again.' }
    $names = @($installed | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
    if ($names -contains $Name) { Write-Host "$Name is already registered; preserving it."; return }
    if ((Test-Path -LiteralPath $Location) -and @(Get-ChildItem -LiteralPath $Location -Force).Count -gt 0) {
        throw "WSL destination is not empty: $Location. Choose another -WSLLocation."
    }
    if ($PSCmdlet.ShouldProcess($Name, "Install NixOS-WSL at $Location")) {
        $tempDirectory = New-SetupTemporaryDirectory
        try {
            $image = Join-Path $tempDirectory 'nixos.wsl'
            Save-VerifiedSetupDownload -Url $Dependency.Url -SHA256 $Dependency.SHA256 -Destination $image
            [void](Invoke-SetupNative -FilePath 'wsl.exe' -ArgumentList @(
                '--install', '--from-file', $image, '--name', $Name, '--location', $Location, '--no-launch'
            ))
        } finally { Remove-SetupTemporaryDirectory -Path $tempDirectory }
    }
}

Export-ModuleMember -Function Get-WindowsSetupInfo, Assert-WindowsSetupSupport, Test-SetupAdministrator,
    Invoke-SetupNative, Save-VerifiedSetupDownload, Remove-SetupTemporaryDirectory, Install-DotfilesPackages,
    Install-DotfilesFont, Merge-SetupObject, Set-DotfilesTerminal, Set-DotfilesPreferences,
    Set-DotfilesStartLayout, Enable-DotfilesWSL, Assert-WSLVersion, Install-DotfilesWSL,
    Assert-ReviOSPlaybook, Start-DotfilesReviOS, Install-DotfilesReviOS, Get-SetupPowerShell7, Invoke-DotfilesUserContinuation
