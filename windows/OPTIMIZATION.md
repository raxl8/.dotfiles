# ReviOS optimization setup

Windows setup uses pinned **ReviOS 26.10** and **AME CLI 0.8.4**. ReviOS supports Windows 11 26H2 (build 26300), 24H2, 25H2 and 26H1. Automatic playbook application requires x64 Windows.

## Automatic application

1. Install Windows/Store updates and restart. Use a stock Windows installation; ReviOS describes conversion of long-used installations as experimental.
2. Setup downloads **ReviOS 26.10** automatically from [this repository's release asset](https://github.com/raxl8/.dotfiles/releases/tag/revios-26.10). This is an unmodified copy of the upstream playbook, with attribution/license/source links in the release. Its hash must match [Revision's published 26.10 checksum](https://github.com/meetrevision/playbook/releases/tag/26.10). Revision's own download uses a browser-facing file host rather than a GitHub binary asset.
3. Turn off Tamper Protection in Windows Security as required by AME.
4. Start elevated 64-bit PowerShell as your own Windows account:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -WhatIf
   powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
   ```
5. Sign in after each required restart. Setup resumes automatically, applies ReviOS and installs personal apps/settings without elevation. After completion, check Windows Security and re-enable Tamper Protection.

Setup verifies download hashes, build compatibility, playbook options, update/restart status, antivirus and AC-power prerequisites. If UCPD is running, its driver/task preparation requires a reboot before playbook application. Temporary Defender preferences are saved and reapplied on success or ordinary failure; ReviOS policies can override their effective values. Application success requires exit zero, the CLI's completion message and installed/pending ReviOS packages.

Without `-ReviOSPlaybook`, setup first accepts `windows/downloads/ReviOS-26.10.apbx` if present, then uses/downloads `%LOCALAPPDATA%\dotfiles\installers\ReviOS-26.10.apbx`. Explicit local files and cached files are verified too. A wrong hash stops setup; it is never silently ignored or overwritten. Delete a corrupt cache only after investigating it, then retry. A failed download stops before applying ReviOS and reports the manual fallback: download the pinned version through [Revision](https://revi.cc/download) and rerun with `-ReviOSPlaybook '<path to .apbx>'`. Preview does not download anything. Release assets and local downloads stay outside Git history.

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
