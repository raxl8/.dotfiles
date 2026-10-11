# Windows setup

## Automatic ReviOS and personal setup

The default **All** stage downloads the SHA256-verified ReviOS playbook, applies it through the pinned AME CLI with the committed options, including Enable Defender, then installs your apps/settings. Finish Windows Update, turn off Tamper Protection in Windows Security as required by AME, then run `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1` from elevated PowerShell as your own account. Required reboots are scheduled with a 30-second warning. Sign in afterward: setup resumes automatically and launches personal setup without elevation. Saved temporary Defender preferences are reapplied; ReviOS policies may override effective values. Check Windows Security and re-enable Tamper Protection after completion. See [ReviOS details](OPTIMIZATION.md).

Use Windows 11 with Windows/Store updates installed, WinGet (App Installer), an internet connection and 64-bit PowerShell. Clone with Git; install Git through WinGet first if needed. All stages can start in Windows PowerShell 5.1. The User stage installs PowerShell 7, Git and Terminal before continuing in installed PowerShell 7 with the same options.

Run the **User** stage as the account whose settings and distributions you want to configure. Elevating as another administrator changes the target account. Close Windows Terminal settings while applying the template, and reopen Terminal afterward.

Use the command's process-scoped execution policy permitted by your device policy. No global execution policy change is needed. Group Policy restrictions are not overridden.

All paths inside setup are resolved from the script location, so the current directory does not have to be the repository root.

## Options

| Option | Effect |
| --- | --- |
| `-Stage All` | Default: ReviOS, automatic reboot continuation, optional WSL preparation, normal-user apps/settings |
| `-SkipReviOS` | All stage: refresh apps/settings on an existing ReviOS installation |
| `-NoRestart` | All stage: restart manually; continuation still runs after sign-in |
| `-Stage ReviOS` | Apply only the verified playbook using AME CLI; x64 Windows only; rerun manually after preparation reboot |
| `-InteractiveReviOS` | With `-Stage ReviOS`, use AME Wizard to select options interactively |
| `-ReviOSPlaybook` | Optional local playbook override; otherwise use the local downloads file, verified cache or automatic release download |
| `-Stage User` | Apply your apps, font and settings after ReviOS |
| `-WhatIf` | Preview; no downloads, installations, registry writes or feature changes |
| `-SkipPackages` | Skip all manifests, including prerequisites; requires installed PowerShell 7 |
| `-SkipEverydayApps` | Omit the everyday app bundle, which installs by default |
| `-IncludeGamingTools` | Install CurseForge, Deadlock Mod Manager, PlayStation Accessories and RTSS |
| `-SkipFont` | Skip the font download/registration |
| `-SkipTerminal` | Skip Terminal settings merging |
| `-SkipPreferences` | Skip dark mode, taskbar and Explorer changes |
| `-ApplyStartLayout` | Opt in to one-time Terminal/Explorer Start pins |
| `-InstallWSL` | All stage: prepare WSL and install NixOS; individual Machine/User stages also accept it |
| `-Stage Machine` | Only prepare WSL when explicitly requested; requires elevation to apply |
| `-DistroName`, `-WSLLocation` | Override optional distribution name and disk location |

Start pins use the documented `ConfigureStartPins` policy file and `applyOnce`. They require a supported Pro/Enterprise/Education/IoT edition, and on 24H2 require KB5062660 or later. The All stage applies this opt-in policy before normal-user setup. Running User separately requests elevation for this policy only; approve as the same account. Home users can customize pins manually. Setup does not delete Start-menu databases. Choose the default terminal application in Terminal Settings > Startup.

## Continuation, logs and recovery

Automatic runs snapshot only the setup scripts/configuration and verified playbook into `C:\Program Files\DotfilesSetup-<run-id>`. Administrators/SYSTEM own and can write the snapshot; ordinary users can read it. The elevated logon task points to this snapshot, not the Git checkout. A separate limited task installs personal apps, including Spotify. Neither task saves a password. Apps are left for your own sign-in.

The snapshot contains `state.json` and `installation.log`. User-stage transcripts are under `%LOCALAPPDATA%\dotfiles\logs`. Tasks are removed on completion or failure; files/logs stay local for diagnosis. A failed run does not retry automatically. Fix its prerequisite, then resume from elevated PowerShell as the original account:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\windows\Install-Windows.ps1 -Resume -RunDirectory '<printed run directory>'
```

To cancel a waiting continuation, use the same command with `-Cancel` instead of `-Resume`. This removes its tasks and keeps logs; it does not undo installed software or ReviOS. The runner stops after six restart boundaries and prevents concurrent automatic runs for the same account. Editing the Git checkout during a run does not update its protected snapshot.

The Terminal template merges managed profiles by GUID, color schemes/themes by name, actions by ID and bindings by keys. Custom entries and unrelated settings survive. Values explicitly defined in the template are applied on each run. JSONC comments and formatting are normalized to JSON; the original file is backed up. The default template does not add a NixOS profile; Terminal discovers it dynamically if you install WSL later.

## Backups and restoring preferences

Changed preferences are journaled before writing under `%LOCALAPPDATA%\dotfiles\backups\<run-id>`. Unchanged registry values are skipped. The original Terminal settings are saved as `terminal-settings.json`. Setup prints the backup directory when it creates one.

Preview and restore the registry preferences from a particular run:

```powershell
pwsh -NoProfile -File .\windows\Restore-Preferences.ps1 -BackupDirectory '<printed backup directory>' -WhatIf
pwsh -NoProfile -File .\windows\Restore-Preferences.ps1 -BackupDirectory '<printed backup directory>'
```

To restore Terminal, close its settings editor, locate its current `settings.json` through Settings > Open JSON file, and replace that file with the backup. Restore multiple runs in reverse order when needed. App/font installation and optimizer changes are outside this preferences journal.

## Before reinstalling Windows

Setup configures Windows after installation. It does not upgrade the OS, prepare a USB installer, erase a disk or recover personal files. To target 26H2 explicitly, create installation media from [Microsoft's official Windows 11 download](https://www.microsoft.com/en-us/software-download/windows11) and select the edition matching your license. A reset using local recovery files should not be treated as a feature-version upgrade.

Keep a verified backup on another device or external drive, separate from the installation USB and the disk being erased. Open representative files from it before proceeding. Keep secrets, inventories and application exports private; never commit them to this repository.

| Save before wiping | Details |
| --- | --- |
| Personal files | Desktop, Documents, Downloads, pictures, videos, recordings, PDFs and custom folders on all relevant drives. Ensure cloud-only files are downloaded if you need an offline copy, and pending uploads have finished. |
| Working projects | Uncommitted, untracked and ignored files, private repositories, local databases, `.env` files, scripts and assets. A Git remote does not contain everything in a working directory. |
| Account recovery | Password-manager access, 2FA recovery codes and another working sign-in method. Check device-bound Windows Hello/passkeys before removing this installation. |
| Encryption and keys | BitLocker recovery keys for every encrypted volume; SSH/GPG private keys if needed; EFS certificates with private keys if used. Save these encrypted outside the public repo. |
| Browser state | Bookmarks, important tabs, extensions/settings and supported password-manager sync/export. Copying a profile does not guarantee that encrypted credentials or sessions work after reinstalling. |
| App configuration | OBS Profiles and Scene Collections plus referenced media/plugins; Anki full `.colpkg` export with media; PowerToys settings backup; editor settings/extensions; Terminal JSON; PowerShell profiles and local assistant configuration. |
| Games | Saves, mods, screenshots and settings. Verify cloud-save coverage per game; an existing game library is not necessarily a saves backup. |
| Extra software | Paid-app licenses and an installation list for tools absent from the manifests. Codex desktop, VS Code, Neovim, Node.js, Python, games and hardware-specific drivers are not installed by this bootstrap. |
| Optional Linux/VM data | Export any WSL data you still need. Shut down VMs before copying their complete disks, firmware state and required configuration. |

For whole-system rollback, also create a system image and working rescue media. The preferences journal below cannot undo ReviOS or reconstruct your old Windows installation. Windows Backup/cloud sync can supplement your backup, but verify application-specific data separately.

On the fresh installation:

1. Boot official x64 26H2 installation media. Select your target by model/capacity and partitions; disk numbers can change. Disconnect backup drives and, where practical, other drives. Delete partitions only on the intended target after verifying the backup. This repo contains no automatic disk selection or wiping commands.
2. Install the licensed Windows edition and complete its supported account setup. The optional answer file below sets locale/time-zone defaults only; it does not launch this bootstrap.
3. Install needed network/chipset/graphics/audio drivers, Windows updates and Store/App Installer updates. Restart until no update restart is pending; verify internet access and activation.
4. Install Git using `winget install --id Git.Git --exact --source winget`, reopen PowerShell, clone `https://github.com/raxl8/.dotfiles.git` and enter the checkout.
5. Turn Tamper Protection off through Windows Security. Open elevated PowerShell as the same account, preview with `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -WhatIf`, then run the same command without `-WhatIf`. The preview is a plan, not a complete prerequisite check.
6. Sign in after required reboots and approve installer UAC prompts. After completion, verify effective Defender protection and re-enable Tamper Protection. Restore personal files/app settings selectively and sign into apps.

Default setup leaves WSL disabled and app accounts signed out. It installs the [listed apps](APPS.md), font, Terminal template and managed Windows preferences. It does not deploy every `.config/` or assistant configuration folder in the repository. Restore your private configuration separately. Choose Windows Terminal as the default terminal application in its Startup settings if desired.

See [VM validation](TESTING.md) for test coverage: the combined flow completed on 26H2, but two QEMU firmware restarts needed host-side cold starts. Some apps were retained rather than freshly installed; physical hardware/drivers, app accounts/features and optional Start-pin behavior are outside the completed validation.

## Optional reinstall media

The filename is **`autounattend.xml`**. Copy `windows/autounattend.xml` to the root of official x64 Windows installation media only if you want its locale/time-zone defaults (`en-US` UI and regional format, US keyboard, Eastern Standard Time). Edit these for your needs. This sets the time-zone ID; it does not reproduce a per-machine daylight-saving override.

Disk/partition selection, Windows edition and account setup stay interactive. Disk configuration and image installation use `WillShowUI=Always`, so you choose the installation target in Windows Setup. Complete the supported Windows account flow. Validate the answer file with Windows System Image Manager against the exact image when updating installation media. Existing Windows installations do not need this file or a reinstall to use the bootstrap.

## Optional WSL

Skip this entire section unless you want WSL. ReviOS/User setup without -InstallWSL does not call `wsl.exe`, enable virtualization features or import NixOS. Omitting `-InstallWSL` preserves any existing distributions.

1. Enable virtualization in firmware if needed. In an elevated PowerShell window:
   ```powershell
   pwsh -NoProfile -File .\setup.ps1 -Stage Machine -InstallWSL -WhatIf
   pwsh -NoProfile -File .\setup.ps1 -Stage Machine -InstallWSL
   ```
2. If setup returns `3010`, restart and rerun the Machine command. It installs/updates Store WSL without adding Ubuntu.
3. In PowerShell as your normal Windows user:
   ```powershell
   pwsh -NoProfile -File .\setup.ps1 -Stage User -InstallWSL
   ```

The pinned `nixos.wsl` image is SHA256-verified and installed with `wsl --install --from-file` (WSL 2.4.4+). An already registered name is preserved. A nonempty installation directory is rejected. The default distribution is not changed. The bundled image and the `#wsl` flake target are x64-only.

For an isolated first rebuild without moving root SSH keys into your user account:

```powershell
wsl -d NixOS
```

Inside the initial `nixos` account, set a password, prepare SSH access to the private flake input, and clone onto the Linux filesystem:

```sh
passwd
mkdir -p ~/git
nix-shell -p git
# Configure and verify GitHub SSH authentication for this account first.
git clone git@github.com:raxl8/.dotfiles.git ~/git/.dotfiles
# Evaluate with this user's SSH identity; build, then activate as root.
nix build --extra-experimental-features 'nix-command flakes' \
  ~/git/.dotfiles#nixosConfigurations.wsl.config.system.build.toplevel
sudo ./result/bin/switch-to-configuration boot
exit
```

Then run `wsl --terminate NixOS` in Windows and reopen it. The flake's `adhesive.user` becomes the configured default user. Keep the original bootstrap account/repo available until you have verified the new account and established its own SSH credentials. Do not blindly move another account's private keys. For subsequent rebuilds, clone the repo into the configured user's `~/git` directory and use the same build/activation flow (with `switch` instead of `boot` when appropriate).

## Clean-machine acceptance

See [the VM validation results](TESTING.md) for the completed default combined flow on 26H2, including its VM firmware restart limitation. Automated tests mock OS mutations; use a disposable VM when changing dependencies or behavior. Additional acceptance checks:

- On a disposable 26H2 VM, run the default All stage once, sign in after each required restart, and verify completion, task cleanup, apps/fonts/Terminal/preferences and effective Defender status. Run `-Stage User` again as a normal user to check retention and settings merging.
- Test failed downloads/installers and confirm setup reports failure without continuing.
- Verify `-WhatIf` and ReviOS/User runs without -InstallWSL leave WSL features/distributions unchanged.
- Test preferences restore and a customized JSONC Terminal file.
- Test optional Start pins on supported Pro, sign in again and verify user edits remain after reruns.
- On a separate VM with virtualization support, test optional WSL across the reboot boundary and preserve an existing NixOS distribution.
- Validate `autounattend.xml` using the exact 26H2 image in Windows SIM before boot-media use.
- Verify AME download/playbook hashes and retest automatic preparation, application and reboot on a stock image. The optional wizard closing must not launch personal setup automatically.

## Sources

- [Windows release information](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information)
- [Official Windows installation media](https://www.microsoft.com/en-us/software-download/windows11)
- [Reinstalling Windows and matching the licensed edition](https://support.microsoft.com/en-us/windows/deployment/install-upgrade/reinstall-windows-with-the-installation-media)
- [BitLocker recovery keys](https://support.microsoft.com/en-us/windows/security/encryption/find-your-bitlocker-recovery-key)
- [Windows passkey management](https://support.microsoft.com/en-us/accounts-billing/security/manage-your-saved-passkeys)
- [OBS Profiles](https://obsproject.com/kb/profiles) and [Scene Collections](https://obsproject.com/kb/scene-collections)
- [Anki collection exports](https://github.com/ankitects/anki/blob/main/docs-site/manual/exporting.mdx)
- [PowerToys settings backup](https://learn.microsoft.com/en-us/windows/powertoys/general)
- [Configure Start Pins policy](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-start#configurestartpins)
- [Start layout and applyOnce](https://learn.microsoft.com/en-us/windows/configuration/start/layout)
- [NixOS-WSL installation](https://nix-community.github.io/NixOS-WSL/install.html)
- [WSL commands](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)
