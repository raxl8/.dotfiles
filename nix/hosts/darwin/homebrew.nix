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
      "stripe-cli"
      "weasyprint"
    ];
    casks = [
      "aegisub"
      "affinity-photo"
      "alcove"
      "android-studio"
      "appcleaner"
      "bartender"
      "clop"
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
      "ghostty@tip"
      "insomnia"
      "karabiner-elements"
      "latest"
      "lookaway"
      "middleclick"
      "notion"
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
      "vlc"
      "zoom"
    ];
  };
}
