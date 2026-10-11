#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-DotfilesProtectedRun {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path) { throw 'Setup run directory already exists.' }
    New-Item -ItemType Directory -Path $Path | Out-Null
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    $admin = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $acl.SetOwner($admin)
    foreach ($sid in @('S-1-5-32-544', 'S-1-5-18', 'S-1-5-32-545')) {
        $rights = if ($sid -eq 'S-1-5-32-545') { 'ReadAndExecute' } else { 'FullControl' }
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            (New-Object Security.Principal.SecurityIdentifier($sid)), $rights, 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
    Assert-DotfilesProtectedRun -Path $Path
}

function Assert-DotfilesProtectedRun {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    if ([IO.Path]::GetDirectoryName($full) -ne $env:ProgramFiles -or
        [IO.Path]::GetFileName($full) -notmatch '^DotfilesSetup-[0-9a-f-]{36}$') { throw 'Invalid protected setup directory.' }
    if ((Get-Item -LiteralPath $full).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Setup directory must not be a link.' }
    $acl = Get-Acl -LiteralPath $full
    $trusted = @('S-1-5-32-544', 'S-1-5-18')
    if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -notin $trusted) { throw 'Setup directory owner must be Administrators or SYSTEM.' }
    $write = [Security.AccessControl.FileSystemRights]::Write -bor [Security.AccessControl.FileSystemRights]::Delete -bor
        [Security.AccessControl.FileSystemRights]::ChangePermissions -bor [Security.AccessControl.FileSystemRights]::TakeOwnership
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
        if ($rule.AccessControlType -eq 'Allow' -and ($rule.FileSystemRights -band $write) -and $rule.IdentityReference.Value -notin $trusted) {
            throw 'An unprivileged account can modify the elevated continuation.'
        }
    }
}

function Save-DotfilesRunState {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Directory, [Parameter(Mandatory)]$State)
    $temp = Join-Path $Directory 'state.new.json'
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination (Join-Path $Directory 'state.json') -Force
}

function Get-DotfilesNextPhase {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('ReviOS', 'User')][string]$Phase, [Parameter(Mandatory)][string]$Result)
    if ($Phase -eq 'ReviOS') {
        switch ($Result) {
            'PreparationRestart' { return 'ReviOS' }
            'AppliedRestart' { return 'Machine' }
            default { throw "Unexpected ReviOS result: $Result" }
        }
    }
    switch ($Result) {
        '0' { return 'Completed' }
        '3010' { return 'User' }
        default { throw "Personal setup failed (exit $Result). Inspect %LOCALAPPDATA%\dotfiles\logs." }
    }
}

function Remove-DotfilesContinuation {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$TaskName)
    foreach ($name in @($TaskName, ($TaskName + '-User'))) {
        if (Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $name -Confirm:$false
        }
    }
}

Export-ModuleMember -Function New-DotfilesProtectedRun, Assert-DotfilesProtectedRun, Save-DotfilesRunState, Get-DotfilesNextPhase, Remove-DotfilesContinuation
