# Windows validation

Validated October 10–11, 2026 on Windows 11 Pro **26H2**, x64, build **26300.9457**, in QEMU 11.1/WHPX. Dependencies: **ReviOS 26.10** and **AME CLI 0.8.4**. The default combined command completed with the VM restart limitations described below.

| Check | Result |
| --- | --- |
| Interactive disk selection | Windows Setup showed both disposable disks and allowed selecting the second. Testing stopped before formatting it. |
| Preview | Windows PowerShell 5.1 previews left apps, fonts, settings and optional features unchanged. |
| Prerequisites and apps | With PowerShell 7 removed, the User stage reinstalled it and continued in PowerShell 7. All **19** default package IDs were present, including freshly installed Spotify; PowerShell 7.6.6 and Git 2.55.0.windows.5 ran successfully. |
| Fonts and settings | 16 font files and their per-user registrations, Terminal font, Explorer preferences and dark mode were verified. |
| WSL default | The WSL feature remained disabled. |
| Unelevated configuration | A normal-user run preserved a custom JSONC Terminal property. Preference backup/restore/reapply worked; subsequent runs preserved the Terminal settings hash. |
| Automatic ReviOS | UCPD preparation requested a reboot before application. AME reported success; five pending packages became installed after reboot. Defender real-time protection was enabled, UCPD stopped/disabled and widget policies disabled. |
| Failure reporting | Setup rejected a real CLI run that logged playbook errors despite exit zero. A nonempty WSL destination failed without changing its marker file; continuation tasks were removed. |
| Optional gaming tools | All four package IDs installed successfully. The VM approved the .NET runtime, PlayStation Accessories and RTSS installer UAC prompts. |
| Start-layout policy | The same-account elevated helper applied the opt-in policy with `applyOnce=true`. Visual pins and preservation of subsequent user pin edits remain unverified. |
| Combined setup | One `setup.ps1 -ReviOSPlaybook <path> -ApplyStartLayout` command reached `Completed` after two restart boundaries, with all default apps/settings and zero continuation tasks. Personal setup ran through a limited task. |
| Continuation protection | `-SkipReviOS` completed on an existing installation. Ordinary-user write attempts against protected scripts/state were denied; owners were Administrators. |
| Windows SIM | ADK/Windows SIM **10.0.26100.9457** generated a catalog from the exact stock 26H2 Pro image. Tools > Validate Answer File reported **No warnings or errors** for the public `autounattend.xml`. No lab image path was added to the public file. |
| Optional WSL | Features enabled and Store WSL **3.0.1** installed/updated. NixOS import failed with `HCS_E_HYPERV_NOT_INSTALLED`: WHPX did not expose nested virtualization; TCG exposed SVM/SLAT but Windows rejected the processor with Hyper-V event **48**. Distribution boot and Nix rebuild remain unverified. |
| Automatic playbook download | On the host, Windows PowerShell 5.1 and PowerShell 7 downloaded the public release asset without authentication, matched the upstream SHA256 and reused the verified cache. Preview created no cache. This acquisition change was tested separately from the VM application flow, which used a local playbook. |
| Automated checks | All **103 Pester tests** passed. Source parsing under Windows PowerShell 5.1/PowerShell 7, PSScriptAnalyzer error checks and `git diff --check` passed. Coverage includes playbook download/cache/failure checks, continuation transitions and native script exit-code propagation. |
| Secret scans | Gitleaks found no secrets in the repository, its history or the exported tracked files. Lab fixtures and logs remain outside the repository. |

## Test limits

The combined flow started from stock Windows with Tamper Protection turned off through Windows Security/UAC and a checksum-verified playbook. Some apps were already installed; PowerShell and Spotify exercised fresh installation. App accounts, application features and physical hardware/drivers were not tested.

Lab-only TPM/Secure Boot bypasses supported the available virtual firmware, and lab-only autologon simulated signing back in. Public setup requires supported Windows installation, manual Tamper Protection preparation and Windows sign-in; it stores no Windows credentials.

QEMU/WHPX firmware resets failed at both setup restarts (`Unexpected VP exit code 4` or stalled firmware). Host-side cold starts of the same disk let continuation finish without rerunning setup commands, consistent with QEMU [issue 2042](https://gitlab.com/qemu-project/qemu/-/issues/2042) and [issue 2402](https://gitlab.com/qemu-project/qemu/-/issues/2402). A private wrapper using [`-no-reboot`](https://www.qemu.org/docs/master/system/invocation.html) and restarting QEMU recovered a subsequent guest reboot automatically, preserving completed setup and enabled Defender. The two original setup restarts still required host intervention; the public scripts contain no VM-specific workaround.
