@{
    # Pinned release assets. Update URL and SHA256 together after upstream review.
    Font = @{
        Url = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.zip'
        SHA256 = 'fab782a66f7d3019da64f6572db9fc5d3a4bcb19f9fa13e2d8a62e3693d6396e'
    }
    WSL = @{
        Url = 'https://github.com/nix-community/NixOS-WSL/releases/download/2605.7.2/nixos.wsl'
        SHA256 = 'e7180ad555fdcb8e1e057e2ef056de467603a5e502ff8531053738371be3f6b9'
    }
    ReviOS = @{
        Version = '26.10'
        ReleaseUrl = 'https://github.com/meetrevision/playbook/releases/tag/26.10'
        # Unmodified upstream playbook; attribution/source links are in this release.
        Url = 'https://github.com/raxl8/.dotfiles/releases/download/revios-26.10/ReviOS-26.10.apbx'
        SHA256 = '7698b591b0b2d46bc99b3ffe9dbd7ec560a3fbee3ec8dee2731caead5546c74a'
        Builds = @(22631, 26100, 26200, 28000, 26300)
    }
    AME = @{
        Url = 'https://github.com/Ameliorated-LLC/trusted-uninstaller-cli/releases/download/0.8.4/AME-Beta-v0.8.4.exe'
        SHA256 = 'a637f32b64e1493b315db9139065105656c84518dca20ce3b18c89750ee40c82'
    }
    AMECLI = @{
        Url = 'https://github.com/Ameliorated-LLC/trusted-uninstaller-cli/releases/download/0.8.4/CLI-Standalone.zip'
        SHA256 = '70e4946b52c9384ca88730c0dd25646defc63affdef7acadd69cb6317f21825a'
    }
}
