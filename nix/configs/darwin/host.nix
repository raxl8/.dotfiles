{ pkgs, user, ... }:
{
  users.users.${user} = {
    uid = 501;
    home = "/Users/${user}";
  };

  users.knownUsers = [ user ];

  system.primaryUser = user;

  system.stateVersion = 6;

  system.defaults = {
    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false;
      AppleScrollerPagingBehavior = true;
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "Always";
      KeyRepeat = 2;
      InitialKeyRepeat = 15;

      "com.apple.mouse.tapBehavior" = 1;
      "com.apple.trackpad.scaling" = 1.5;
    };
    finder = {
      _FXSortFoldersFirst = true;
      AppleShowAllExtensions = true;
      FXDefaultSearchScope = "SCcf";
      FXPreferredViewStyle = "Nlsv";
      NewWindowTarget = "Other";
      NewWindowTargetPath = "/Users/${user}/Downloads";
      ShowPathbar = true;
      ShowStatusBar = true;
    };
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.0;
      minimize-to-application = true;
      orientation = "right";
      persistent-apps = [ ];
      persistent-others = [ ];
      show-recents = false;
    };
    controlcenter.BatteryShowPercentage = true;
    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
    };
    WindowManager = {
      EnableTiledWindowMargins = false;
      EnableStandardClickToShowDesktop = false;
    };
  };

  power.sleep = {
    computer = 20;
    display = 20;
    harddisk = 20;
  };

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    gnutar
    xz
  ];

  imports = [
    ./homebrew.nix
  ];
}
