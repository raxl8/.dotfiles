{ ... }:
{
  homebrew = {
    enable = true;
    global = {
      autoUpdate = true;
    };
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      extraFlags = [ "--force" ];
    };
    brews = [
      "cloudflared"
      "glab"
      "mas"
      "mktorrent"
      "mpv"
      "pkgconf"
      "render"
      "stripe-cli"
      "tflint"
      "uhubctl"
      "weasyprint"
      {
        name = "libpq";
        link = true;
      }
    ];
    casks = [
      "aegisub"
      "affinity-photo"
      "alcove"
      "android-studio"
      "anki"
      "anydesk"
      "appcleaner"
      "balenaetcher"
      "bartender"
      "batfi"
      "claude"
      "clop"
      "cleanshot"
      "codex"
      "conductor"
      "cursor"
      "cursor-cli"
      "discord"
      {
        name = "docker-desktop";
        args = {
          no_binaries = true;
        };
      }
      "finicky"
      "firefox"
      "flux-app"
      "gcloud-cli"
      "ghostty@tip"
      "gitbutler"
      "helium"
      "insomnia"
      "karabiner-elements"
      "kiro"
      "latest"
      "linear"
      "lookaway"
      "middleclick"
      "microsoft-office"
      "microsoft-teams"
      "muzzle"
      "notion"
      "obsidian"
      "proton-drive"
      "proton-mail-bridge"
      "proton-pass"
      "protonvpn"
      "qbittorrent"
      "raycast"
      "rustdesk"
      "screen-studio"
      "session-manager-plugin"
      "shottr"
      "slack"
      "tradingview"
      "vanilla"
      "visual-studio-code"
      "vlc"
      "wispr-flow"
      "zoom"
    ];
    masApps = {
      "Dropover" = 1355679052;
      "Hand Mirror" = 1502839586;
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "Parcel 2" = 375589283;
      "PDFgear" = 6469021132;
      "PreviewText" = 1660037028;
      "ScreenBrush" = 1233965871;
      "Telegram" = 747648890;
      "WhatsApp" = 310633997;
      "Windows App" = 1295203466;
      "Xcode" = 497799835;
    };
  };
}
