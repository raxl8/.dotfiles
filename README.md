# .dotfiles

Personal Windows, NixOS-WSL and macOS development configuration. **Windows setup applies ReviOS, then installs apps/settings, and resumes after required reboots. WSL is optional and disabled by default.** Apps can stay signed out.

## Windows quick start

Target: Windows 11 26H2 with ReviOS 26.10. The bootstrap also accepts 24H2, 25H2 and 26H1; the optional NixOS image is x64-only. See [VM validation](windows/TESTING.md) for tested behavior and remaining limits.

1. Install Windows from an official Microsoft image, complete account setup, install Windows/Store updates and restart.
2. Install Git if needed with `winget install --id Git.Git --exact --source winget`, reopen PowerShell, and clone the repository:
   ```powershell
   git clone https://github.com/raxl8/.dotfiles.git
   cd .dotfiles
   ```
3. AME requires Tamper Protection off; change that setting in Windows Security. Start elevated PowerShell **as your own Windows account**, then preview and run:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -WhatIf
   powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
   ```
   Setup downloads the pinned, unmodified **ReviOS 26.10** playbook from [this repository's attributed release asset](https://github.com/raxl8/.dotfiles/releases/tag/revios-26.10), verifies its upstream SHA256 and uses the SHA256-verified AME CLI. It applies the fixed [ReviOS profile](windows/config/revios-options.json), including **Enable Defender**, without wizard prompts. It saves progress, schedules required reboots with a 30-second warning, and resumes when you sign in. Apps/settings run through a temporary task **without elevation**, starting in Windows PowerShell 5.1 and continuing in installed PowerShell 7. No stage commands need to be rerun. WSL is not enabled.
4. Sign in after each reboot and approve any installer UAC prompts. After completion, check Windows Security and re-enable Tamper Protection. Application account sign-in is up to you.

The User stage installs Windows Terminal, PowerShell 7, Git, Steam, Discord and UniGetUI, installs JetBrains Mono Nerd Font for the current user, merges the Catppuccin Terminal template, enables dark mode, centers the taskbar, hides taskbar search and shows file extensions. WinGet may request UAC for individual machine-wide installers. Existing package versions are retained; update apps separately with WinGet or UniGetUI.

Everyday apps also install by default: Helium, PowerToys, Proton Drive/VPN, Tailscale, OBS, Slack, Notion, Anki, PDFgear, f.lux, TradingView and Spotify. Use `-SkipEverydayApps` to omit that bundle, or add `-IncludeGamingTools` for gaming utilities. See [app selection](windows/APPS.md) for app lists and manual hardware-specific steps. On an existing ReviOS installation, use `-SkipReviOS`, or run `-Stage User` directly as a normal user to refresh only personal setup.

The default `All` stage uses a protected snapshot under `C:\Program Files\DotfilesSetup-<run-id>`, retains logs/state locally, and removes its temporary scheduled tasks on completion or failure. `-NoRestart` leaves reboots to you while preserving continuation after sign-in. It does not save Windows credentials or enable autologon. Disk selection, Windows account setup, Tamper Protection and occasional installer UAC prompts remain interactive. WSL features/distributions are untouched unless `-InstallWSL` is selected.

Before wiping a PC, follow the [backup and clean-install checklist](windows/README.md#before-reinstalling-windows). This script configures an installed Windows system; it does not upgrade Windows, create installation media, erase disks or restore personal data. If downloading fails, obtain the pinned playbook through [Revision](https://revi.cc/download) and pass `-ReviOSPlaybook '<path to .apbx>'`. A local `windows/downloads/ReviOS-26.10.apbx` is also accepted; every copy must match the pinned hash.

For troubleshooting, `-Stage ReviOS`, `-Stage Machine` and `-Stage User` remain available separately. These individual stages report `3010` when you must restart and rerun the stage; a successful ReviOS application requires reboot before User. `1` means failure and `0` means completion or preview. Use `-Stage ReviOS -InteractiveReviOS` for the optional wizard; closing it is not proof of installation.

See [Windows setup details](windows/README.md) for switches, backups, reinstall media and optional WSL. See [ReviOS setup](windows/OPTIMIZATION.md) for the pinned release and supported optimization workflow.

## Repository layout

| Path | Purpose |
| --- | --- |
| `setup.ps1` | Windows entry point; automatic ReviOS/apps/settings by default |
| `windows/Install-Windows.ps1` | Protected snapshot and continuation across reboots |
| `windows/config/` | App manifest, Terminal/Start templates, pinned download hashes |
| `windows/Modules/` | Windows setup operations and failure handling |
| `tests/` | Setup behavior tests; no application of system tweaks |
| `flake.nix`, `flake.lock` | Locked Nix inputs and host outputs |
| `nix/shared/` | Shared Nix/Home Manager modules |
| `nix/hosts/darwin/` | macOS host configuration |
| `nix/hosts/wsl/` | Optional NixOS-WSL configuration |
| `.config/`, `.agents/`, `.claude/`, `.codex/` | Application and assistant configuration |

The Nix flake uses the private SSH input `.dotfiles-adhesive`; authorize GitHub SSH access before evaluating it. Keep `flake.lock` committed. Existing NixOS/Home Manager `stateVersion` values represent migration baselines, not the current release; do not bump them simply to update packages.

## Nix hosts

For an existing macOS installation with Nix and private-input SSH access:

```sh
sudo darwin-rebuild switch --flake .#darwin
```

For WSL installation and first rebuild, follow [the optional WSL instructions](windows/README.md#optional-wsl). Windows setup does not evaluate the Nix flake.

## Validation

The Windows workflow parses setup scripts with Windows PowerShell 5.1, analyzes them with PSScriptAnalyzer and runs mocked tests with PowerShell 7/Pester 5.7.1. Locally:

```powershell
Import-Module Pester -RequiredVersion 5.7.1
Invoke-Pester -Path .\tests -CI
```

See [VM validation](windows/TESTING.md) and [the acceptance checklist](windows/README.md#clean-machine-acceptance) when updating setup or its dependencies.
