# Windows app selection

User setup installs these bundles with exact WinGet package IDs. Versions are omitted so missing apps install the current available release. Already installed apps are retained; update apps separately with WinGet or UniGetUI.

| Manifest | Apps | Selection |
| --- | --- | --- |
| `essentials.json` | PowerShell 7, Git, Windows Terminal | Default |
| `packages.json` | UniGetUI, Steam, Discord | Default |
| `everyday-apps.json` | Helium, PowerToys, Proton Drive, Proton VPN, Tailscale, OBS, Slack, Notion, Anki, PDFgear, f.lux, TradingView, Spotify | Default; omit with `-SkipEverydayApps` |
| `gaming-tools.json` | CurseForge, Deadlock Mod Manager, PlayStation Accessories, RivaTuner Statistics Server | `-IncludeGamingTools` |

Everyday apps are included in a normal User run. To add gaming utilities too:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -Stage User -IncludeGamingTools -WhatIf
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -Stage User -IncludeGamingTools
```

`-SkipPackages` skips all manifests, including prerequisites, and requires PowerShell 7 already installed; Terminal must also be installed unless its settings are skipped. Start a new Terminal session after setup to pick up installers' PATH changes. Configure Git identity/credentials and application sign-ins locally.

Install graphics/audio drivers and controller support for the actual hardware. Install games through their launchers and let app installers manage runtime dependencies. Restore Store apps through Microsoft Store and browser apps through the browser. Application accounts, profiles, licenses and private configuration are outside these reusable manifests.

Keep downloaded playbooks, disk images, logs and settings backups outside version control. Never copy browser profiles, tokens, private keys, machine inventories or VM credentials into this public repository.

ReviOS runs before these app bundles. Its [component removal choices](OPTIMIZATION.md#revios-profile) include bundled/Store apps; personal setup installs the desktop `Spotify.Spotify` package afterward.
