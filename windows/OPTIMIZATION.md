# ReviOS optimization setup

Windows setup uses pinned **ReviOS 26.10** and **AME CLI 0.8.4**. ReviOS supports Windows 11 26H2 (build 26300), 24H2, 25H2 and 26H1. Automatic playbook application requires x64 Windows.

## Automatic application

1. Install Windows/Store updates and restart. Use a stock Windows installation; ReviOS describes conversion of long-used installations as experimental.
2. Download **ReviOS 26.10** from [Revision](https://revi.cc/download). Save it to `windows/downloads/ReviOS-26.10.apbx` or pass its location.
3. Turn off Tamper Protection in Windows Security as required by AME.
4. Start elevated 64-bit PowerShell as your own Windows account:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -WhatIf
   powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -ReviOSPlaybook 'C:\Downloads\ReviOS.apbx'
   ```
5. Sign in after each required restart. Setup resumes automatically, applies ReviOS and installs personal apps/settings without elevation. After completion, check Windows Security and re-enable Tamper Protection.

Setup verifies download hashes, build compatibility, playbook options, update/restart status, antivirus and AC-power prerequisites. If UCPD is running, its driver/task preparation requires a reboot before playbook application. Temporary Defender preferences are saved and reapplied on success or ordinary failure; ReviOS policies can override their effective values. Application success requires exit zero, the CLI's completion message and installed/pending ReviOS packages.

Use `-NoRestart` for manual reboots or `-Stage ReviOS` to apply only the playbook. The individual ReviOS stage returns `3010` when you must restart and rerun it. See [setup options and continuation recovery](README.md).

## ReviOS profile

`windows/config/revios-options.json` enables Defender, disables hibernation/Fast Startup, removes Edge, OneDrive, AI, Teams, Photos, Dev Home, Xbox apps and Phone Link, enables dark mode and the legacy context menu, and removes pinned Start items. Automatic Maintenance stays enabled. Helium installs through the everyday-app manifest; WSL is opt-in.

ReviOS also removes [bundled/Store apps](https://github.com/meetrevision/playbook/blob/26.10/src/Configuration/Tasks/packages/appx.yml) and changes SmartScreen, Smart App Control, VBS/HVCI, Credential Guard and automatic device encryption. Enable Defender does not undo all upstream security changes. Review the pinned release's options and retest when editing this profile.

## Interactive alternative and recovery

Use `-Stage ReviOS -InteractiveReviOS` to run the verified AME Wizard and select options yourself. Closing the wizard does not establish successful installation.

Automatic run files are retained under `%LOCALAPPDATA%\dotfiles\installers\revios-<run-id>`. Setup prints `installation.log`; the CLI's own `Log.yml` is in the adjacent `cli` directory. Preparation-only runs save `ucpd-preparation-backup.json`. `defender-preparation-backup.json` contains only the three temporary preferences, not account credentials. A killed process or power loss can prevent `finally` from running. After fixing the failure, reapply those local preferences from an elevated shell:

```powershell
$saved = Get-Content '<run directory>\defender-preparation-backup.json' -Raw | ConvertFrom-Json
Set-MpPreference -DisableRealtimeMonitoring ([bool]$saved.DisableRealtimeMonitoring) -MAPSReporting ([int]$saved.MAPSReporting) -SubmitSamplesConsent ([int]$saved.SubmitSamplesConsent)
```

Check Windows Security after reboot and re-enable Tamper Protection. Do not proceed to personal setup after a failed playbook. OS changes are outside this repo's preferences journal; use the VM checkpoint or your system backup for full rollback.

Update dependency URL/hash pairs together in `windows/config/dependencies.psd1`, using official releases and testing on a disposable machine. See [validation evidence](TESTING.md) for what was actually exercised.

## Sources

- [ReviOS 26.10 release and checksum](https://github.com/meetrevision/playbook/releases/tag/26.10)
- [ReviOS supported builds/downloads](https://revi.cc/download)
- [ReviOS installation guide](https://revi.cc/docs/playbook/install)
- [ReviOS feature/security changes](https://revi.cc/docs/features)
- [ReviOS option definitions](https://github.com/meetrevision/playbook/blob/26.10/src/playbook.conf)
- [AME CLI usage](https://github.com/Ameliorated-LLC/trusted-uninstaller-cli#cli-usage)
- [AME CLI 0.8.4 release](https://github.com/Ameliorated-LLC/trusted-uninstaller-cli/releases/tag/0.8.4)
- [Microsoft Tamper Protection](https://learn.microsoft.com/en-us/defender-endpoint/prevent-changes-to-security-settings-with-tamper-protection)
- [Microsoft Windows release information](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information)
