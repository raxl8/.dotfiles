# note: can't use %temp% because atlas will delete it during installation
$tempDir = Join-Path -Path $env:SystemDrive -ChildPath $([System.Guid]::NewGuid())
New-Item -Force -ItemType Directory -Path $tempDir | Out-Null
Push-Location $tempDir

# Download faster plz
$ProgressPreference = 'SilentlyContinue'

# Download 7zip to extract 7zip :)
# (7zr can't extract archive with password)
Write-Host "Downloading 7zip..."

$url = "https://github.com/ip7z/7zip/releases/download/24.09/7zr.exe"
Invoke-WebRequest -Uri $url -OutFile .\7zr.exe

$url = "https://github.com/ip7z/7zip/releases/download/24.09/7z2409-extra.7z"
Invoke-WebRequest -Uri $url -OutFile .\7zip.7z
.\7zr.exe -y x 7zip.7z -o7zip | Out-Null
Remove-Item -Force .\7zip.7z

Remove-Item -Force .\7zr.exe

$7zipPath = ".\7zip\x64\7za.exe"

Write-Host "Downloading ReviOS playbook..."

$url = "https://github.com/meetrevision/playbook/releases/download/25.10/Revi-PB-25.10.apbx"
Invoke-WebRequest -Uri $url -OutFile .\playbook.apbx
& $7zipPath -y x playbook.apbx -oplaybook -pmalte | Out-Null
Remove-Item -Force .\playbook.apbx

Write-Host "Downloading TrustedUninstaller..."

$url = "https://github.com/Ameliorated-LLC/trusted-uninstaller-cli/releases/download/0.8.1/CLI-Standalone.zip"
Invoke-WebRequest -Uri $url -OutFile .\trusted-uninstaller.zip
& $7zipPath -y x trusted-uninstaller.zip -oTrustedUninstaller | Out-Null
Remove-Item -Force .\trusted-uninstaller.zip

Remove-Item -Force .\7zip -Recurse

Write-Host "Installing Atlas playbook..."

$playbookOptions = @(
  "enable-defender"
  "disable-hibernate"
  "remove-edge"
  "remove-onedrive"
  "remove-winsxs-ai"
  "remove-teams"
  "remove-appx-photos"
  "remove-appx-devhome"
  "remove-appx-xbox"
  "remove-appx-yourphone"
  "configure-darkmode"
  "configure-lcm"
  "remove-pinned-items-startmenu"
  "disable-automatic-maintenance"
)
.\TrustedUninstaller\TrustedUninstaller.CLI.exe "$((Resolve-Path .\playbook).Path)" @playbookOptions

Remove-Item -Force .\playbook -Recurse

Pop-Location

Write-Host "Installing WSL..."

wsl.exe --install --no-distribution

Write-Host "Installing scheduled task to run playbook on boot..."

$customPlaybookPath = (Resolve-Path .\windows\playbook).Path
$installPlaybookPath = (Resolve-Path .\windows\installPlaybook.ps1).Path
$taskTitle = "InstallPlaybook"
$taskArgs = "/c schtasks /delete /tn `"$taskTitle`" /f > nul & " + `
    "powershell.exe -NoProfile -ExecutionPolicy Bypass " + `
    "-Command `"& '$installPlaybookPath' '$tempDir' '$customPlaybookPath'`""
$task = @{
  "TaskName" = $taskTitle
  "Settings" = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
  "Trigger" = New-ScheduledTaskTrigger -AtLogOn
  "User" = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  "Force" = $true
  "RunLevel" = "Highest"
  "Action" = New-ScheduledTaskAction -Execute "cmd.exe" -Argument $taskArgs
}
Register-ScheduledTask @task | Out-Null

Write-Host "First step of setup done, computer will now reboot, press any key to continue" -ForegroundColor Green
Read-Host

Restart-Computer -Force
