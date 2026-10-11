BeforeDiscovery {
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'windows/Modules/Dotfiles.Windows.psm1') -Force
}
BeforeAll {
    $script:repoRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $repoRoot 'windows/Modules/Dotfiles.Windows.psm1')
}

Describe 'Automatic ReviOS requirements' {
    InModuleScope Dotfiles.Windows {
        BeforeEach {
            Mock Test-SetupAdministrator { $true }
            Mock Get-MpComputerStatus { @{ IsTamperProtected = $false } }
            Mock Test-Path { $false }
            Mock Get-CimInstance { @() }
        }
        It 'rejects an unelevated run' {
            Mock Test-SetupAdministrator { $false }
            { Assert-ReviOSAutomaticRequirements } | Should -Throw '*elevated*'
            Should -Invoke Get-MpComputerStatus -Times 0
        }
        It 'rejects Tamper Protection before querying other requirements' {
            Mock Get-MpComputerStatus { @{ IsTamperProtected = $true } }
            { Assert-ReviOSAutomaticRequirements } | Should -Throw '*Tamper Protection*'
            Should -Invoke Get-CimInstance -Times 0
        }
        It 'rejects pending update restarts' {
            Mock Test-Path { $true }
            { Assert-ReviOSAutomaticRequirements } | Should -Throw '*pending restart*'
        }
        It 'rejects another antivirus' {
            Mock Get-CimInstance { @{ displayName = 'Other Antivirus' } } -ParameterFilter { $ClassName -eq 'AntiVirusProduct' }
            { Assert-ReviOSAutomaticRequirements } | Should -Throw '*third-party antivirus*'
        }
        It 'rejects a discharging battery' {
            Mock Get-CimInstance { @{ BatteryStatus = 1 } } -ParameterFilter { $ClassName -eq 'Win32_Battery' }
            { Assert-ReviOSAutomaticRequirements } | Should -Throw '*AC power*'
        }
        It 'accepts the prepared desktop state' {
            Mock Get-CimInstance { @{ displayName = 'Windows Defender' } } -ParameterFilter { $ClassName -eq 'AntiVirusProduct' }
            { Assert-ReviOSAutomaticRequirements } | Should -Not -Throw
        }
    }
}

Describe 'ReviOS UCPD reboot preparation' {
    InModuleScope Dotfiles.Windows {
        BeforeEach {
            $script:driverMode = 'System'
            Mock Get-CimInstance { @{ State = 'Running'; StartMode = $script:driverMode } }
            Mock Get-ScheduledTask { @{ State = 'Ready' } }
            Mock Disable-ScheduledTask { }
            Mock Invoke-SetupNative { $script:driverMode = 'Disabled'; 0 }
        }
        It 'stages the same UCPD changes as ReviOS and requires a reboot' {
            Initialize-ReviOSUCPD -BackupDirectory $TestDrive | Should -BeTrue
            Should -Invoke Invoke-SetupNative -Times 1 -ParameterFilter { $FilePath -eq 'sc.exe' -and ($ArgumentList -join ' ') -eq 'config UCPD start= disabled' }
            Should -Invoke Disable-ScheduledTask -Times 1
            Test-Path (Join-Path $TestDrive 'ucpd-preparation-backup.json') | Should -BeTrue
        }
        It 'does not reconfigure a driver that is already stopped' {
            Mock Get-CimInstance { @{ State = 'Stopped'; StartMode = 'Disabled' } }
            Initialize-ReviOSUCPD -BackupDirectory $TestDrive | Should -BeFalse
            Should -Invoke Invoke-SetupNative -Times 0
            Should -Invoke Disable-ScheduledTask -Times 0
        }
        It 'still requires reboot if disabled startup has not unloaded the driver' {
            $script:driverMode = 'Disabled'
            Mock Get-ScheduledTask { @{ State = 'Disabled' } }
            Initialize-ReviOSUCPD -BackupDirectory $TestDrive | Should -BeTrue
            Should -Invoke Invoke-SetupNative -Times 0
            Should -Invoke Disable-ScheduledTask -Times 0
        }
        It 'keeps preparation previews inert' {
            Initialize-ReviOSUCPD -BackupDirectory $TestDrive -WhatIf | Should -BeFalse
            Should -Invoke Invoke-SetupNative -Times 0
            Should -Invoke Disable-ScheduledTask -Times 0
        }
    }
}

Describe 'ReviOS completion evidence' {
    InModuleScope Dotfiles.Windows {
        BeforeEach {
            $script:log = Join-Path $TestDrive 'cli.log'
            Mock Get-WindowsPackage { @{ PackageName = 'Revision-ReviOS-Components'; PackageState = 'Installed' } }
        }
        It 'does not accept exit zero when upstream reports errors' {
            'Playbook completed with errors.' | Set-Content $log
            { Assert-ReviOSCompletion -ExitCode 0 -LogPath $log } | Should -Throw '*did not complete*'
            Should -Invoke Get-WindowsPackage -Times 0
        }
        It 'does not mistake preparation or an old package for a completed installation' {
            'Preparation Complete' | Set-Content $log
            { Assert-ReviOSCompletion -ExitCode 0 -LogPath $log } | Should -Throw '*did not complete*'
        }
        It 'rejects nonzero even with a success message' {
            'Playbook completed successfully.' | Set-Content $log
            { Assert-ReviOSCompletion -ExitCode 1 -LogPath $log } | Should -Throw '*did not complete*'
        }
        It 'requires installed ReviOS packages after the success message' {
            'Playbook completed successfully.' | Set-Content $log
            Mock Get-WindowsPackage { @() }
            { Assert-ReviOSCompletion -ExitCode 0 -LogPath $log } | Should -Throw '*no installed or restart-pending ReviOS packages*'
        }
        It 'accepts successful completion with <PackageState> packages and a required reboot' -ForEach @(@{ PackageState = 'Installed' }, @{ PackageState = 'InstallPending' }) {
            'Playbook completed successfully.' | Set-Content $log
            Mock Get-WindowsPackage { @{ PackageName = 'Revision-ReviOS-Components'; PackageState = $PackageState } }
            { Assert-ReviOSCompletion -ExitCode 0 -LogPath $log } | Should -Not -Throw
        }
    }
}

Describe 'Automatic ReviOS execution and recovery' {
    InModuleScope Dotfiles.Windows {
        BeforeEach {
            $script:oldLocalAppData = $env:LOCALAPPDATA
            $env:LOCALAPPDATA = $TestDrive
            $script:originalPreferences = @{ DisableRealtimeMonitoring = $false; MAPSReporting = 2; SubmitSamplesConsent = 1 }
            $script:prepared = $false
            $script:revi = @{ Version = '26.10'; Builds = @(26300) }
            $script:cliDependency = @{ Url = 'https://example.invalid/cli.zip'; SHA256 = '0' * 64 }
            $script:optionsPath = Join-Path $TestDrive 'options.json'
            '["enable-defender"]' | Set-Content $optionsPath
            Mock Get-WindowsSetupInfo { @{ Build = 26300; Architecture = 'AMD64' } }
            Mock Assert-ReviOSPlaybook { }
            Mock Assert-ReviOSAutomaticRequirements { }
            Mock Initialize-ReviOSUCPD { $false }
            Mock Save-VerifiedSetupDownload { }
            Mock Expand-Archive { }
            Mock Expand-ReviOSCLIPlaybook { }
            Mock Resolve-Path { @{ Path = 'C:\Example\ReviOS.apbx' } }
            Mock Invoke-ReviOSCLI { }
            Mock Start-Sleep { }
            Mock Get-MpComputerStatus { @{ RealTimeProtectionEnabled = $false } }
            Mock Get-MpPreference {
                if ($script:prepared) { @{ DisableRealtimeMonitoring = $true; MAPSReporting = 0; SubmitSamplesConsent = 2 } }
                else { $script:originalPreferences }
            }
            Mock Set-MpPreference { $script:prepared = [bool]$DisableRealtimeMonitoring }
        }
        AfterEach { $env:LOCALAPPDATA = $script:oldLocalAppData }
        It 'keeps automatic previews inert, including Defender' {
            Install-DotfilesReviOS -PlaybookPath missing.apbx -Dependency $revi -CLIDependency $cliDependency -OptionsPath missing.json -WhatIf | Should -BeFalse
            Should -Invoke Assert-ReviOSAutomaticRequirements -Times 0
            Should -Invoke Save-VerifiedSetupDownload -Times 0
            Should -Invoke Set-MpPreference -Times 0
            Should -Invoke Invoke-ReviOSCLI -Times 0
        }
        It 'restores preparation preferences after successful application' {
            Install-DotfilesReviOS -PlaybookPath valid.apbx -Dependency $revi -CLIDependency $cliDependency -OptionsPath $optionsPath | Should -Be 'AppliedRestart'
            Should -Invoke Invoke-ReviOSCLI -Times 1
            Should -Invoke Set-MpPreference -Times 1 -ParameterFilter { -not $DisableRealtimeMonitoring -and $MAPSReporting -eq 2 -and $SubmitSamplesConsent -eq 1 }
        }
        It 'restores preparation preferences after a failed application' {
            Mock Invoke-ReviOSCLI { throw 'Playbook failure' }
            { Install-DotfilesReviOS -PlaybookPath valid.apbx -Dependency $revi -CLIDependency $cliDependency -OptionsPath $optionsPath } | Should -Throw '*Playbook failure*'
            Should -Invoke Set-MpPreference -Times 1 -ParameterFilter { -not $DisableRealtimeMonitoring -and $MAPSReporting -eq 2 -and $SubmitSamplesConsent -eq 1 }
        }
        It 'refuses to launch if Windows did not actually accept preparation' {
            Mock Get-MpComputerStatus { @{ RealTimeProtectionEnabled = $true } }
            { Install-DotfilesReviOS -PlaybookPath valid.apbx -Dependency $revi -CLIDependency $cliDependency -OptionsPath $optionsPath } | Should -Throw '*did not accept*'
            Should -Invoke Invoke-ReviOSCLI -Times 0
            Should -Invoke Set-MpPreference -Times 1 -ParameterFilter { -not $DisableRealtimeMonitoring }
        }
        It 'stops before changing Defender when download verification fails' {
            Mock Save-VerifiedSetupDownload { throw 'SHA256 mismatch' }
            { Install-DotfilesReviOS -PlaybookPath valid.apbx -Dependency $revi -CLIDependency $cliDependency -OptionsPath $optionsPath } | Should -Throw '*SHA256 mismatch*'
            Should -Invoke Set-MpPreference -Times 0
        }
        It 'reports the preparation reboot without launching a playbook or changing Defender' {
            Mock Initialize-ReviOSUCPD { $true }
            Install-DotfilesReviOS -PlaybookPath valid.apbx -Dependency $revi -CLIDependency $cliDependency -OptionsPath $optionsPath | Should -Be 'PreparationRestart'
            Should -Invoke Save-VerifiedSetupDownload -Times 0
            Should -Invoke Set-MpPreference -Times 0
            Should -Invoke Invoke-ReviOSCLI -Times 0
        }
    }
}

Describe 'ReviOS and everyday application profile' {
    It 'enumerates every option consistently in Windows PowerShell 5.1 and PowerShell 7' {
        $runner = Join-Path $TestDrive 'read-options.ps1'
        @'
param($ModulePath, $OptionsPath)
Import-Module $ModulePath
& (Get-Module Dotfiles.Windows) {
    param($Path)
    $values = @(Get-ReviOSOptions -Path $Path)
    if ($values.Count -ne 13 -or $values[0] -ne 'enable-defender' -or $values[-1] -ne 'remove-pinned-items-startmenu') { throw 'Options were collapsed or changed' }
} $OptionsPath
'OPTIONS ENUMERATED'
'@ | Set-Content $runner
        foreach ($shell in @('powershell.exe', (Join-Path $PSHOME 'pwsh.exe'))) {
            $output = & $shell -NoProfile -ExecutionPolicy Bypass -File $runner (Join-Path $repoRoot 'windows/Modules/Dotfiles.Windows.psm1') (Join-Path $repoRoot 'windows/config/revios-options.json') 2>&1
            $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
            ($output -join "`n") | Should -Match 'OPTIONS ENUMERATED'
        }
    }
    It 'keeps Defender enabled and Automatic Maintenance enabled' {
        $options = @(Get-Content (Join-Path $repoRoot 'windows/config/revios-options.json') -Raw | ConvertFrom-Json)
        $options | Should -Contain 'enable-defender'
        $options | Should -Not -Contain 'disable-defender'
        $options | Should -Not -Contain 'disable-automatic-maintenance'
    }
    It 'installs Spotify in the default everyday bundle' {
        $manifest = Get-Content (Join-Path $repoRoot 'windows/config/everyday-apps.json') -Raw | ConvertFrom-Json
        $manifest.Sources.Packages.PackageIdentifier | Should -Contain 'Spotify.Spotify'
    }
}
