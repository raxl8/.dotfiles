{
  pkgs,
  user,
  stateVersion,
  ...
}:
{
  home.username = user;

  home.packages = with pkgs; [
    clang
    fzf
    nixfmt-rfc-style
    ripgrep
    rustup
    unzip
  ];

  xdg.enable = true;

  home.stateVersion = stateVersion;
  home.file.".local/bin/tmux-sessionizer.nu" = {
    source = ./scripts/tmux-sessionizer.nu;
    executable = true;
  };

  imports = [
    ./pkgs
  ];
}
