BeforeDiscovery {
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'windows/Modules/Dotfiles.Windows.psm1')
}
BeforeAll {
    $script:repoRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $script:repoRoot 'windows/Modules/Dotfiles.Windows.psm1')
}

Describe 'Windows support guards' {
    It 'accepts 26H2 without enabling WSL' {
        { Assert-WindowsSetupSupport -Info @{ Build = 26300; DisplayVersion = '26H2'; Architecture = 'AMD64' } } | Should -Not -Throw
    }
    It 'rejects obsolete Windows builds' {
        { Assert-WindowsSetupSupport -Info @{ Build = 22631; DisplayVersion = '23H2' } } | Should -Throw '*24H2*'
    }
    It 'supports native ARM64 but rejects the x64 NixOS image on ARM64' {
        $info = @{ Build = 28000; DisplayVersion = '26H1'; Architecture = 'ARM64' }
        { Assert-WindowsSetupSupport -Info $info } | Should -Not -Throw
        { Assert-WindowsSetupSupport -Info $info -InstallWSL } | Should -Throw '*x64-only*'
    }
}

Describe 'Default ReviOS workflow' {
    It 'previews the individual ReviOS stage under Windows PowerShell 5.1' {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'setup.ps1') -Stage ReviOS -WhatIf 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'stage: ReviOS'
        ($output -join "`n") | Should -Not -Match 'Install using WinGet|VirtualMachinePlatform|Install NixOS-WSL'
    }
    It 'previews personal setup under PowerShell 7 without WSL' {
        $output = & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File (Join-Path $repoRoot 'setup.ps1') -Stage User -WhatIf 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'Preview complete'
        ($output -join "`n") | Should -Not -Match 'VirtualMachinePlatform|Install NixOS-WSL'
    }
    InModuleScope Dotfiles.Windows {
        BeforeEach {
            Mock Get-WindowsSetupInfo { return @{ Build = 26300 } }
            Mock Start-Process { }
            Mock Save-VerifiedSetupDownload { }
            $script:revi = @{ Version = '26.10'; Builds = @(26300); SHA256 = '0' * 64; ReleaseUrl = 'https://github.com/meetrevision/playbook/releases/tag/26.10' }
            $script:wizard = @{ Url = 'https://example.invalid/AME.exe'; SHA256 = '0' * 64 }
        }
        It 'previews ReviOS without downloading, launching or requiring local assets' {
            Start-DotfilesReviOS -PlaybookPath 'missing.apbx' -Dependency $revi -WizardDependency $wizard -WhatIf
            Should -Invoke Start-Process -Times 0
            Should -Invoke Save-VerifiedSetupDownload -Times 0
        }
        It 'rejects unsupported builds before any downloads' {
            Mock Get-WindowsSetupInfo { return @{ Build = 99999 } }
            { Start-DotfilesReviOS -PlaybookPath 'missing.apbx' -Dependency $revi -WizardDependency $wizard } | Should -Throw '*does not declare support*'
            Should -Invoke Save-VerifiedSetupDownload -Times 0
        }
        It 'stops on a missing playbook instead of silently falling back' {
            { Start-DotfilesReviOS -PlaybookPath (Join-Path $TestDrive 'missing.apbx') -Dependency $revi -WizardDependency $wizard } | Should -Throw '*Download ReviOS*'
            Should -Invoke Start-Process -Times 0
        }
        It 'rejects an untrusted playbook' {
            $path = Join-Path $TestDrive 'bad.apbx'
            'unexpected playbook' | Set-Content $path
            { Start-DotfilesReviOS -PlaybookPath $path -Dependency $revi -WizardDependency $wizard } | Should -Throw '*does not match pinned*'
            Should -Invoke Start-Process -Times 0
            Should -Invoke Save-VerifiedSetupDownload -Times 0
        }
        It 'accepts a matching pinned playbook' {
            $path = Join-Path $TestDrive 'valid.apbx'
            'trusted sample' | Set-Content $path
            $revi.SHA256 = (Get-FileHash $path).Hash
            { Assert-ReviOSPlaybook -Path $path -Dependency $revi } | Should -Not -Throw
        }
        It 'verifies the cached wizard and launches only the interactive handoff' {
            Mock Assert-ReviOSPlaybook { }
            Mock New-Item { }
            Mock Test-Path { return $true }
            Mock Get-FileHash { return @{ Hash = '0' * 64 } }
            Mock Resolve-Path { return @{ Path = 'C:\Downloads\ReviOS.apbx' } }
            Start-DotfilesReviOS -PlaybookPath 'ReviOS.apbx' -Dependency $revi -WizardDependency $wizard
            Should -Invoke Save-VerifiedSetupDownload -Times 0
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $Verb -eq 'RunAs' -and $Wait }
        }
        It 'refuses to launch AME when its download verification fails' {
            Mock Assert-ReviOSPlaybook { }
            Mock New-Item { }
            Mock Test-Path { return $false }
            Mock Save-VerifiedSetupDownload { throw 'SHA256 mismatch' }
            { Start-DotfilesReviOS -PlaybookPath 'ReviOS.apbx' -Dependency $revi -WizardDependency $wizard } | Should -Throw '*SHA256 mismatch*'
            Should -Invoke Start-Process -Times 0
        }
    }
}

Describe 'Automatic playbook download' {
    InModuleScope Dotfiles.Windows {
        BeforeEach {
            $script:originalLocalAppData = $env:LOCALAPPDATA
            $env:LOCALAPPDATA = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            $script:sample = Join-Path $TestDrive 'sample.apbx'
            'trusted sample' | Set-Content $sample
            $script:dependency = @{ Version = 'test'; SHA256 = (Get-FileHash $sample).Hash; Url = 'https://example.invalid/playbook.apbx'; ReleaseUrl = 'https://example.invalid/release' }
            Mock Save-VerifiedSetupDownload { Copy-Item -LiteralPath $script:sample -Destination $Destination }
        }
        AfterEach { $env:LOCALAPPDATA = $script:originalLocalAppData }
        It 'downloads and verifies the pinned asset when no path or cache exists' {
            $path = Resolve-DotfilesReviOSPlaybook -Dependency $dependency
            (Get-FileHash $path).Hash | Should -Be $dependency.SHA256
            Should -Invoke Save-VerifiedSetupDownload -Times 1 -Exactly -ParameterFilter { $Url -eq $dependency.Url -and $SHA256 -eq $dependency.SHA256 }
        }
        It 'reuses the verified cache without another download' {
            $path = Resolve-DotfilesReviOSPlaybook -Dependency $dependency
            Resolve-DotfilesReviOSPlaybook -Dependency $dependency | Should -Be $path
            Should -Invoke Save-VerifiedSetupDownload -Times 1 -Exactly
        }
        It 'uses an explicit verified file without downloading' {
            Resolve-DotfilesReviOSPlaybook -Path $sample -Dependency $dependency | Should -Be $sample
            Should -Invoke Save-VerifiedSetupDownload -Times 0
        }
        It 'does not replace a missing explicit file with a download' {
            { Resolve-DotfilesReviOSPlaybook -Path (Join-Path $TestDrive 'missing.apbx') -Dependency $dependency } | Should -Throw '*Download ReviOS*'
            Should -Invoke Save-VerifiedSetupDownload -Times 0
        }
        It 'rejects a corrupt cache instead of using it' {
            $path = Resolve-DotfilesReviOSPlaybook -Dependency $dependency
            'corrupt' | Set-Content $path
            { Resolve-DotfilesReviOSPlaybook -Dependency $dependency } | Should -Throw '*does not match pinned*'
            Should -Invoke Save-VerifiedSetupDownload -Times 1 -Exactly
        }
        It 'rejects a downloaded file with the wrong checksum' {
            Mock Save-VerifiedSetupDownload { 'corrupt' | Set-Content $Destination }
            { Resolve-DotfilesReviOSPlaybook -Dependency $dependency } | Should -Throw '*does not match pinned*'
        }
        It 'reports download failure with the local-file recovery command' {
            Mock Save-VerifiedSetupDownload { throw 'HTTP 403' }
            { Resolve-DotfilesReviOSPlaybook -Dependency $dependency } | Should -Throw '*Automatic ReviOS download failed*ReviOSPlaybook*'
        }
        It 'previews without creating a cache or downloading' {
            Resolve-DotfilesReviOSPlaybook -Dependency $dependency -WhatIf
            Should -Invoke Save-VerifiedSetupDownload -Times 0
            Test-Path (Join-Path $env:LOCALAPPDATA 'dotfiles\installers') | Should -BeFalse
        }
    }
}

Describe 'Native command errors' {
    It 'fails on nonzero exit codes instead of continuing setup' {
        { Invoke-SetupNative -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList @('-NoProfile', '-Command', 'exit 7') } | Should -Throw '*exit code 7*'
    }
    It 'allows explicitly recognized return codes' {
        Invoke-SetupNative -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList @('-NoProfile', '-Command', 'exit 7') -SuccessCodes @(7) | Should -Be 7
    }
    It 'handles expected native codes even when native error preference is enabled' {
        $PSNativeCommandUseErrorActionPreference = $true
        Invoke-SetupNative -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList @('-NoProfile', '-Command', 'exit 7') -SuccessCodes @(7) | Should -Be 7
    }
}

Describe 'PowerShell bootstrap continuation' {
    It 'keeps previews inert when invoked from another PowerShell script' {
        $sandbox = Join-Path $TestDrive 'nested preview'
        $modules = Join-Path $sandbox 'windows/Modules'
        New-Item -ItemType Directory -Path $modules -Force | Out-Null
        Copy-Item (Join-Path $repoRoot 'setup.ps1') $sandbox
        Copy-Item (Join-Path $repoRoot 'windows/config') (Join-Path $sandbox 'windows/config') -Recurse
        # Retain the real module's preview guards; trap any attempted OS mutation.
        $source = Get-Content (Join-Path $repoRoot 'windows/Modules/Dotfiles.Windows.psm1') -Raw
        $source += @'

function Get-WindowsSetupInfo { @{ DisplayVersion = '26H2'; Build = 26300; Edition = 'Professional'; Architecture = 'AMD64' } }
function Test-SetupAdministrator { $false }
function Invoke-SetupNative { throw 'Unexpected native mutation in preview' }
function Save-VerifiedSetupDownload { throw 'Unexpected download in preview' }
function Assert-ReviOSPlaybook { throw 'Unexpected playbook access in preview' }
function Get-WindowsOptionalFeature { @{ State = 'Disabled' } }
function Enable-WindowsOptionalFeature { throw 'Unexpected feature mutation in preview' }
function Set-SetupRegistryValue {
    [CmdletBinding(SupportsShouldProcess)]
    param($Path, $Name, $Value, $Type, $BackupDirectory)
    if ($PSCmdlet.ShouldProcess($Path, 'Registry preview')) { throw 'Unexpected registry mutation in preview' }
}
'@
        Set-Content (Join-Path $modules 'Dotfiles.Windows.psm1') $source
        $wrapper = @'
& (Join-Path $PSScriptRoot 'setup.ps1') -Stage ReviOS -WhatIf
if ($LASTEXITCODE -ne 0) { exit 1 }
& (Join-Path $PSScriptRoot 'setup.ps1') -Stage User -WhatIf
if ($LASTEXITCODE -ne 0) { exit 1 }
& (Join-Path $PSScriptRoot 'setup.ps1') -Stage User -ApplyStartLayout -WhatIf
if ($LASTEXITCODE -ne 0) { exit 1 }
& (Join-Path $PSScriptRoot 'setup.ps1') -Stage Machine -InstallWSL -WhatIf
if ($LASTEXITCODE -ne 0) { exit 1 }
'NESTED PREVIEWS COMPLETE'
'@
        $wrapperPath = Join-Path $sandbox 'preview.ps1'
        Set-Content $wrapperPath $wrapper
        foreach ($shell in @('powershell.exe', (Join-Path $PSHOME 'pwsh.exe'))) {
            $output = & $shell -NoProfile -ExecutionPolicy Bypass -File $wrapperPath 2>&1
            $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
            ($output -join "`n") | Should -Match 'NESTED PREVIEWS COMPLETE'
            ($output -join "`n") | Should -Not -Match 'Unexpected .* preview'
        }
    }
    It 'installs prerequisites before a real 5.1-to-7 handoff and preserves app selection (skip everyday: <SkipEveryday>)' -ForEach @(@{ SkipEveryday = $false }, @{ SkipEveryday = $true }) {
        # Use the real entry point and child process, but replace every OS mutation.
        $sandbox = Join-Path $TestDrive ("bootstrap with spaces $SkipEveryday")
        $modules = Join-Path $sandbox 'windows/Modules'
        New-Item -ItemType Directory -Path $modules -Force | Out-Null
        Copy-Item (Join-Path $repoRoot 'setup.ps1') $sandbox
        Copy-Item (Join-Path $repoRoot 'windows/config') (Join-Path $sandbox 'windows/config') -Recurse
        $stub = @'
function Get-WindowsSetupInfo { @{ DisplayVersion = '25H2'; Build = 26200 } }
function Assert-WindowsSetupSupport { param($Info, [switch]$InstallWSL) }
function Test-SetupAdministrator { $false }
function Install-DotfilesPackages {
    param($ManifestPath)
    Add-Content (Join-Path $PSScriptRoot '../../trace.txt') "packages:$([IO.Path]::GetFileName($ManifestPath)):PS$($PSVersionTable.PSVersion.Major)"
    $false
}
function Get-SetupPowerShell7 {
    Add-Content (Join-Path $PSScriptRoot '../../trace.txt') 'handoff'
    $env:DOTFILES_TEST_PWSH
}
function Set-DotfilesTerminal {
    param($TemplatePath, $BackupDirectory)
    if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Terminal ran before handoff' }
    Add-Content (Join-Path $PSScriptRoot '../../trace.txt') 'terminal:PS7'
}
function Assert-WSLVersion { }
function Install-DotfilesWSL {
    param($Dependency, $Name, $Location)
    Add-Content (Join-Path $PSScriptRoot '../../trace.txt') "wsl:$Name|$Location"
}
'@
        foreach ($name in @('Invoke-SetupNative', 'Invoke-DotfilesUserContinuation')) {
            $stub += "`nfunction $name {`n" + (Get-Command $name).Definition + "`n}`n"
        }
        $stub += "`nExport-ModuleMember -Function *`n"
        Set-Content (Join-Path $modules 'Dotfiles.Windows.psm1') $stub
        $previous = $env:DOTFILES_TEST_PWSH
        try {
            $env:DOTFILES_TEST_PWSH = Join-Path $PSHOME 'pwsh.exe'
            $appOptions = @()
            if ($SkipEveryday) { $appOptions += '-SkipEverydayApps' }
            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $sandbox 'setup.ps1') -Stage User -InstallWSL -IncludeGamingTools -SkipFont -SkipPreferences -DistroName 'Custom' -WSLLocation 'D:\WSL files\Custom' @appOptions 2>&1
            $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
        } finally { $env:DOTFILES_TEST_PWSH = $previous }
        $trace = @(Get-Content (Join-Path $sandbox 'trace.txt'))
        $trace[0] | Should -Be 'packages:essentials.json:PS5'
        $trace[1] | Should -Be 'handoff'
        if ($SkipEveryday) { $trace | Should -Not -Contain 'packages:everyday-apps.json:PS7' }
        else { $trace | Should -Contain 'packages:everyday-apps.json:PS7' }
        $trace | Should -Contain 'packages:gaming-tools.json:PS7'
        $trace | Should -Contain 'terminal:PS7'
        $trace | Should -Contain 'wsl:Custom|D:\WSL files\Custom'
    }
    It 'previews full personal setup from Windows PowerShell 5.1 before pwsh is installed' {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'setup.ps1') -Stage User -IncludeGamingTools -WhatIf 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'Git.Git'
        ($output -join "`n") | Should -Match 'Microsoft.PowerShell'
        ($output -join "`n") | Should -Match 'ImputNet.Helium'
        ($output -join "`n") | Should -Not -Match 'Continuing personal setup|Install NixOS-WSL'
    }
    InModuleScope Dotfiles.Windows {
        It 'passes paths with spaces as separate arguments and retains optional switches' {
            Mock Invoke-SetupNative { return 0 }
            Invoke-DotfilesUserContinuation -PowerShellPath 'C:\Program Files\PowerShell\7\pwsh.exe' -ScriptPath 'C:\my dotfiles\setup.ps1' -Parameters @{
                InstallWSL = $true; SkipEverydayApps = $true; IncludeGamingTools = $true
                SkipFont = $true; SkipTerminal = $false; DistroName = 'Custom'
                WSLLocation = 'D:\WSL files\Custom'
            } | Should -Be 0
            Should -Invoke Invoke-SetupNative -Times 1 -Exactly -ParameterFilter {
                $ArgumentList -contains 'C:\my dotfiles\setup.ps1' -and
                $ArgumentList -contains 'D:\WSL files\Custom' -and
                $ArgumentList -contains '-InstallWSL' -and
                $ArgumentList -contains '-SkipEverydayApps' -and
                $ArgumentList -contains '-IncludeGamingTools' -and
                $ArgumentList -contains '-SkipFont' -and
                $ArgumentList -notcontains '-SkipTerminal'
            }
        }
        It 'propagates failure and reboot exit codes from the child' -ForEach @(@{ Code = 1 }, @{ Code = 3010 }) {
            $script:childCode = $Code
            Mock Invoke-SetupNative { return $script:childCode }
            Invoke-DotfilesUserContinuation -PowerShellPath 'pwsh.exe' -ScriptPath 'setup.ps1' -Parameters @{} | Should -Be $Code
        }
        It 'reports missing installed PowerShell without falling back to the process PATH' {
            Mock Test-Path { return $false }
            { Get-SetupPowerShell7 } | Should -Throw '*installed locations*'
        }
        It 'finds installed PowerShell after an installer changed PATH outside the current process' {
            Mock Test-Path { return $LiteralPath -eq (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe') }
            Mock Get-Item { return @{ VersionInfo = @{ ProductVersion = '7.5.4' } } }
            Get-SetupPowerShell7 | Should -Be (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe')
        }
    }
}

Describe 'Terminal merge preserves user configuration' {
    BeforeEach {
        $script:current = @'
{
  // JSONC and trailing commas are intentional.
  "customSetting": true,
  "profiles": {
    "defaults": { "font": { "size": 12, "weight": "bold" } },
    "list": [
      { "guid": "custom", "name": "My shell" },
      { "guid": "managed", "name": "Old name", "startingDirectory": "D:/code" },
    ]
  },
  "schemes": [{ "name": "My colors", "background": "#111111" }],
  "actions": [{ "id": "custom.action", "command": "paste" }]
}
'@ | ConvertFrom-Json -AsHashtable
        $script:template = @'
{
  "profiles": {
    "defaults": { "font": { "size": 16, "face": "JetBrainsMono Nerd Font" } },
    "list": [{ "guid": "managed", "name": "PowerShell" }]
  },
  "schemes": [{ "name": "Catppuccin Mocha", "background": "#1E1E2E" }],
  "actions": [{ "id": "managed.action", "command": "copy" }]
}
'@ | ConvertFrom-Json -AsHashtable
    }
    It 'merges nested defaults while retaining unrelated properties' {
        Merge-SetupObject -Current $current -Template $template
        $current.customSetting | Should -BeTrue
        $current.profiles.defaults.font.weight | Should -Be 'bold'
        $current.profiles.defaults.font.size | Should -Be 16
    }
    It 'keeps custom profiles and updates managed profiles by GUID' {
        Merge-SetupObject -Current $current -Template $template
        $current.profiles.list.Count | Should -Be 2
        $current.profiles.list[0].name | Should -Be 'My shell'
        $current.profiles.list[1].name | Should -Be 'PowerShell'
        $current.profiles.list[1].startingDirectory | Should -Be 'D:/code'
    }
    It 'keeps custom schemes and actions' {
        Merge-SetupObject -Current $current -Template $template
        $current.schemes.Count | Should -Be 2
        $current.schemes[0].name | Should -Be 'My colors'
        $current.actions.Count | Should -Be 2
    }
    It 'does not duplicate managed entries on reruns' {
        Merge-SetupObject -Current $current -Template $template
        $before = $current | ConvertTo-Json -Depth 100 -Compress
        Merge-SetupObject -Current $current -Template $template
        ($current | ConvertTo-Json -Depth 100 -Compress) | Should -Be $before
    }
}

Describe 'WinGet package setup' {
    InModuleScope Dotfiles.Windows {
        BeforeAll {
            function winget.exe { }
            $script:manifestPath = Join-Path $TestDrive 'packages.json'
            '{"Sources":[{"SourceDetails":{"Name":"winget"},"Packages":[{"PackageIdentifier":"Microsoft.PowerShell"},{"PackageIdentifier":"Valve.Steam"}]}]}' | Set-Content $manifestPath
        }
        BeforeEach { Mock Invoke-SetupNative { return 0 } }
        It 'does not run WinGet during WhatIf' {
            Install-DotfilesPackages -ManifestPath $manifestPath -WhatIf | Should -BeFalse
            Should -Invoke Invoke-SetupNative -Times 0
        }
        It 'installs silently with exact identifiers and avoids implicit upgrades' {
            Install-DotfilesPackages -ManifestPath $manifestPath | Should -BeFalse
            Should -Invoke Invoke-SetupNative -Times 2 -Exactly -ParameterFilter {
                $ArgumentList -contains '--exact' -and $ArgumentList -contains '--no-upgrade' -and $ArgumentList -contains '--silent'
            }
        }
        It 'stops further packages at a reboot boundary' {
            Mock Invoke-SetupNative { return 3010 }
            Install-DotfilesPackages -ManifestPath $manifestPath | Should -BeTrue
            Should -Invoke Invoke-SetupNative -Times 1 -Exactly
        }
        It 'recognizes both WinGet already-installed HRESULTs' {
            Install-DotfilesPackages -ManifestPath $manifestPath | Should -BeFalse
            Should -Invoke Invoke-SetupNative -Times 2 -Exactly -ParameterFilter {
                $SuccessCodes -contains -1978335189 -and $SuccessCodes -contains -1978335135
            }
        }
        It 'handles WinGet wrapped reboot codes' -ForEach @(@{ Code = -1978334967 }, @{ Code = -1978334966 }, @{ Code = -1978334965 }) {
            $script:rebootCode = $Code
            Mock Invoke-SetupNative { return $script:rebootCode }
            Install-DotfilesPackages -ManifestPath $manifestPath | Should -BeTrue
            Should -Invoke Invoke-SetupNative -Times 1 -Exactly
        }
        It 'stops after a failed installer' {
            Mock Invoke-SetupNative { throw 'installer failed' }
            { Install-DotfilesPackages -ManifestPath $manifestPath } | Should -Throw '*installer failed*'
            Should -Invoke Invoke-SetupNative -Times 1 -Exactly
        }
    }
}

Describe 'Verified downloads and cleanup' {
    InModuleScope Dotfiles.Windows {
        It 'rejects a mismatched hash and removes the download' {
            Mock Invoke-WebRequest { Set-Content -LiteralPath $OutFile -Value 'unexpected contents' }
            $path = Join-Path $TestDrive 'download.bin'
            { Save-VerifiedSetupDownload -Url 'https://example.invalid/file' -SHA256 ('0' * 64) -Destination $path } | Should -Throw '*SHA256 mismatch*'
            Test-Path -LiteralPath $path | Should -BeFalse
        }
        It 'accepts the expected hash' {
            Mock Invoke-WebRequest { Set-Content -LiteralPath $OutFile -Value 'verified contents' }
            $sample = Join-Path $TestDrive 'sample.bin'
            Set-Content -LiteralPath $sample -Value 'verified contents'
            $path = Join-Path $TestDrive 'download.bin'
            $hash = (Get-FileHash -LiteralPath $sample).Hash
            Save-VerifiedSetupDownload -Url 'https://example.invalid/file' -SHA256 $hash -Destination $path
            Test-Path -LiteralPath $path | Should -BeTrue
        }
        It 'rejects non-HTTPS downloads before fetching' {
            Mock Invoke-WebRequest { throw 'must not fetch' }
            { Save-VerifiedSetupDownload -Url 'http://example.invalid/file' -SHA256 ('0' * 64) -Destination (Join-Path $TestDrive 'bad.bin') } | Should -Throw '*HTTPS*'
            Should -Invoke Invoke-WebRequest -Times 0
        }
        It 'never removes a directory outside its own temporary workspace' {
            Mock Remove-Item { throw 'must not remove' }
            { Remove-SetupTemporaryDirectory -Path $TestDrive } | Should -Throw '*Refusing*'
            Should -Invoke Remove-Item -Times 0
        }
        It 'skips font downloads and file operations during WhatIf' {
            Mock Save-VerifiedSetupDownload { throw 'must not fetch' }
            Mock New-SetupTemporaryDirectory { throw 'must not write' }
            Install-DotfilesFont -Dependency @{} -WhatIf
            Should -Invoke Save-VerifiedSetupDownload -Times 0
            Should -Invoke New-SetupTemporaryDirectory -Times 0
        }
    }
}

Describe 'WSL version detection' {
    InModuleScope Dotfiles.Windows {
        BeforeAll { function wsl.exe { } }
        It 'accepts current WSL with redirected UTF-16 NUL characters' {
            Mock wsl.exe { $global:LASTEXITCODE = 0; return ('WSL version: 3.0.1.0'.ToCharArray() -join "`0") }
            { Assert-WSLVersion } | Should -Not -Throw
        }
        It 'rejects a version without from-file support' {
            Mock wsl.exe { $global:LASTEXITCODE = 0; return 'WSL version: 2.3.0.0' }
            { Assert-WSLVersion } | Should -Throw '*2.4.4*'
        }
        It 'reports a failed version command' {
            Mock wsl.exe { $global:LASTEXITCODE = 1; return 'WSL version: 3.0.1.0' }
            { Assert-WSLVersion } | Should -Throw '*Prepare WSL first*'
        }
    }
}

Describe 'Optional WSL setup' {
    InModuleScope Dotfiles.Windows {
        BeforeAll { function wsl.exe { } }
        BeforeEach {
            Mock Assert-WSLVersion { }
            Mock Save-VerifiedSetupDownload { }
            Mock Invoke-SetupNative { return 0 }
        }
        It 'does not run WSL or download an image during WhatIf' {
            Mock wsl.exe { throw 'must not run' }
            Install-DotfilesWSL -Dependency @{} -Name 'NixOS' -Location (Join-Path $TestDrive 'NixOS') -WhatIf
            Should -Invoke wsl.exe -Times 0
            Should -Invoke Save-VerifiedSetupDownload -Times 0
        }
        It 'preserves an already registered distribution, including UTF16 NULs' {
            Mock wsl.exe { $global:LASTEXITCODE = 0; return "N`0i`0x`0O`0S`0" }
            Install-DotfilesWSL -Dependency @{} -Name 'NixOS' -Location (Join-Path $TestDrive 'NixOS')
            Should -Invoke Save-VerifiedSetupDownload -Times 0
            Should -Invoke Invoke-SetupNative -Times 0
        }
        It 'rejects a nonempty target directory' {
            Mock wsl.exe { $global:LASTEXITCODE = 0; return 'Ubuntu' }
            $location = Join-Path $TestDrive 'nonempty'
            New-Item -ItemType Directory -Path $location -Force | Out-Null
            'keep me' | Set-Content (Join-Path $location 'important.txt')
            { Install-DotfilesWSL -Dependency @{} -Name 'NixOS' -Location $location } | Should -Throw '*not empty*'
            Should -Invoke Save-VerifiedSetupDownload -Times 0
        }
        It 'installs a .wsl file through the supported from-file interface' {
            Mock wsl.exe { $global:LASTEXITCODE = 0; return 'Ubuntu' }
            Install-DotfilesWSL -Dependency @{ Url = 'https://example.invalid/nixos.wsl'; SHA256 = '0' * 64 } -Name 'NixOS' -Location (Join-Path $TestDrive 'new')
            Should -Invoke Invoke-SetupNative -Times 1 -Exactly -ParameterFilter {
                $ArgumentList -contains '--from-file' -and $ArgumentList -contains '--no-launch' -and $ArgumentList -notcontains '--import'
            }
        }
        It 'reports WSL list failures instead of overwriting a distribution' {
            Mock wsl.exe { $global:LASTEXITCODE = 1 }
            { Install-DotfilesWSL -Dependency @{} -Name 'NixOS' -Location (Join-Path $TestDrive 'new') } | Should -Throw '*Could not list*'
            Should -Invoke Invoke-SetupNative -Times 0
        }
        It 'does not touch Windows features during WhatIf' {
            Mock Get-WindowsOptionalFeature { throw 'must not query DISM' }
            Enable-DotfilesWSL -WhatIf | Should -BeFalse
            Should -Invoke Get-WindowsOptionalFeature -Times 0
            Should -Invoke Invoke-SetupNative -Times 0
        }
        It 'waits for a pending feature reboot before invoking WSL' {
            Mock Get-WindowsOptionalFeature { return @{ State = 'EnablePending' } }
            Enable-DotfilesWSL | Should -BeTrue
            Should -Invoke Invoke-SetupNative -Times 0
        }
    }
}

Describe 'Start layout guards and backup preview' {
    InModuleScope Dotfiles.Windows {
        It 'elevates only the policy helper for an unelevated user' {
            Mock Test-SetupAdministrator { return $false }
            Mock Start-Process { return @{ ExitCode = 0 } }
            Mock Set-SetupRegistryValue { throw 'Do not write protected policy unelevated' }
            $layoutPath = Join-Path $TestDrive 'start-layout.json'
            '{"applyOnce":true,"pinnedList":[]}' | Set-Content $layoutPath
            Set-DotfilesStartLayout -LayoutPath $layoutPath -Info @{ Edition = 'Professional'; Build = 26300 } -BackupDirectory $TestDrive
            Should -Invoke Start-Process -Times 1 -ParameterFilter { $Verb -eq 'RunAs' -and $ArgumentList -contains '-EncodedCommand' }
            Should -Invoke Set-SetupRegistryValue -Times 0
        }
        It 'rejects Home edition without applying a policy' {
            Mock Set-SetupRegistryValue { }
            { Set-DotfilesStartLayout -LayoutPath 'unused' -Info @{ Edition = 'Core'; Build = 26300 } -BackupDirectory $TestDrive } | Should -Throw '*Pro*'
            Should -Invoke Set-SetupRegistryValue -Times 0
        }
        It 'requires the applyOnce update on 24H2' {
            { Set-DotfilesStartLayout -LayoutPath 'unused' -Info @{ Edition = 'Professional'; Build = 26100; Revision = 1000 } -BackupDirectory $TestDrive } | Should -Throw '*KB5062660*'
        }
        It 'does not write registry backups during WhatIf' {
            Mock Get-Item { return $null }
            Mock New-Item { throw 'must not create' }
            Mock New-ItemProperty { throw 'must not write' }
            # Call the real helper instead of the mock used in other tests.
            $function = Get-Command Set-SetupRegistryValue -CommandType Function
            & $function -Path 'HKCU:\Software\Example' -Name 'Value' -Value 0 -BackupDirectory $TestDrive -WhatIf
            Should -Invoke New-Item -Times 0
            Should -Invoke New-ItemProperty -Times 0
        }
    }
}

Describe 'Configuration consistency' {
    It 'uses a one-time Start layout with correctly cased app IDs' {
        $layout = Get-Content (Join-Path $repoRoot 'windows/config/start-layout.json') -Raw | ConvertFrom-Json -AsHashtable
        $layout.applyOnce | Should -BeTrue
        $layout.pinnedList[0].Keys | Should -Contain 'packagedAppID'
    }
    It 'does not bundle a NixOS Terminal profile into the default setup' {
        $template = Get-Content (Join-Path $repoRoot 'windows/config/terminal.json') -Raw | ConvertFrom-Json
        @($template.profiles.list | Where-Object source -eq 'Windows.Terminal.Wsl').Count | Should -Be 0
    }
    It 'leaves disk and account selection to Windows Setup' {
        [xml]$answer = Get-Content (Join-Path $repoRoot 'windows/autounattend.xml') -Raw
        $answer.SelectNodes('//*[local-name()="Disk" or local-name()="DiskID" or local-name()="PartitionID" or local-name()="WillWipeDisk" or local-name()="InstallTo" or local-name()="InstallToAvailablePartition" or local-name()="CreatePartitions" or local-name()="ModifyPartitions" or local-name()="AutoLogon" or local-name()="LocalAccounts" or local-name()="RunSynchronous"]').Count | Should -Be 0
        $answer.SelectSingleNode('//*[local-name()="DiskConfiguration"]/*[local-name()="WillShowUI"]').InnerText | Should -Be 'Always'
        $answer.SelectSingleNode('//*[local-name()="OSImage"]/*[local-name()="WillShowUI"]').InnerText | Should -Be 'Always'
    }
    It 'parses all setup PowerShell sources' {
        $files = @((Join-Path $repoRoot 'setup.ps1')) + @(Get-ChildItem (Join-Path $repoRoot 'windows') -Recurse -File -Include *.ps1,*.psm1,*.psd1 | ForEach-Object FullName)
        foreach ($file in $files) {
            $tokens = $null; $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors) | Out-Null
            @($errors).Count | Should -Be 0 -Because $file
        }
    }
}
