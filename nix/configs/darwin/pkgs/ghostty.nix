{ pkgs, inputs, ... }:
{
  programs.ghostty = {
    enable = true;

    package = null;

    settings = {
      theme = "Catppuccin Mocha";
      font-size = 20;
      maximize = true;
    };
  };
}
