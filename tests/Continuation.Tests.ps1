BeforeDiscovery {
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'windows/Modules/Dotfiles.Continuation.psm1') -Force
}
BeforeAll {
    $script:repoRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $repoRoot 'windows/Modules/Dotfiles.Continuation.psm1') -Force
}

Describe 'Automatic setup continuation' {
    It 'previews without scheduling tasks or requiring elevation' {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'windows/Install-Windows.ps1') -WhatIf 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'temporary logon continuation'
    }
    It 'uses the full automatic flow by default from the root entry point' {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'setup.ps1') -WhatIf 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'temporary logon continuation'
    }
    It 'preserves the coordinator exit code across the root script boundary' -TestCases @(@{Code=0},@{Code=1},@{Code=3010}) {
        param($Code)
        $directory = Join-Path $TestDrive "exit-$Code"
        New-Item -ItemType Directory -Path (Join-Path $directory 'windows\Modules') -Force | Out-Null
        Copy-Item (Join-Path $repoRoot 'setup.ps1') $directory
        Copy-Item (Join-Path $repoRoot 'windows\Modules\Dotfiles.Windows.psm1') (Join-Path $directory 'windows\Modules')
        "exit $Code" | Set-Content (Join-Path $directory 'windows\Install-Windows.ps1')
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $directory 'setup.ps1')
        $LASTEXITCODE | Should -Be $Code
    }
    It 'keeps ReviOS active after preparation but advances after verified application' {
        Get-DotfilesNextPhase -Phase ReviOS -Result PreparationRestart | Should -Be ReviOS
        Get-DotfilesNextPhase -Phase ReviOS -Result AppliedRestart | Should -Be Machine
        { Get-DotfilesNextPhase -Phase ReviOS -Result '0' } | Should -Throw '*Unexpected ReviOS*'
    }
    It 'retries User only after a required reboot and rejects failures' {
        Get-DotfilesNextPhase -Phase User -Result 3010 | Should -Be User
        Get-DotfilesNextPhase -Phase User -Result 0 | Should -Be Completed
        { Get-DotfilesNextPhase -Phase User -Result 1 } | Should -Throw '*failed*'
        { Get-DotfilesNextPhase -Phase User -Result 267009 } | Should -Throw '*failed*'
    }
    It 'rejects continuations in a writable checkout' {
        { Assert-DotfilesProtectedRun -Path $repoRoot } | Should -Throw '*Invalid protected*'
    }
    It 'persists the selected options and replaces the prior state' {
        $directory = Join-Path $TestDrive 'run'
        New-Item -ItemType Directory -Path $directory | Out-Null
        Save-DotfilesRunState -Directory $directory -State @{ Phase = 'ReviOS'; Options = @{InstallWSL=$false;IncludeGamingTools=$true} }
        Save-DotfilesRunState -Directory $directory -State @{ Phase = 'Machine'; Options = @{InstallWSL=$false;IncludeGamingTools=$true} }
        $saved = Get-Content (Join-Path $directory 'state.json') -Raw | ConvertFrom-Json
        $saved.Phase | Should -Be Machine
        $saved.Options.InstallWSL | Should -BeFalse
        $saved.Options.IncludeGamingTools | Should -BeTrue
        Test-Path (Join-Path $directory 'state.new.json') | Should -BeFalse
    }
    It 'preserves the boot marker as a string across JSON reloads' {
        $marker = 'boot-2026-10-11T12:34:56.1234567Z'
        Save-DotfilesRunState -Directory $TestDrive -State @{WaitingBoot=$marker}
        $saved = Get-Content (Join-Path $TestDrive 'state.json') -Raw | ConvertFrom-Json
        $saved.WaitingBoot | Should -BeOfType ([string])
        $saved.WaitingBoot | Should -Be $marker
    }
    InModuleScope Dotfiles.Continuation {
        It 'removes only its own coordinator and worker tasks' {
            Mock Get-ScheduledTask { @{TaskName=$TaskName} }
            Mock Unregister-ScheduledTask {}
            Remove-DotfilesContinuation -TaskName 'DotfilesSetup-fixture'
            Should -Invoke Unregister-ScheduledTask -Times 1 -Exactly -ParameterFilter { $TaskName -eq 'DotfilesSetup-fixture' -and -not $Confirm }
            Should -Invoke Unregister-ScheduledTask -Times 1 -Exactly -ParameterFilter { $TaskName -eq 'DotfilesSetup-fixture-User' -and -not $Confirm }
        }
    }
}
