{ adhesive, pkgs, ... }:
{
  programs.awscli = {
    enable = true;

    settings = adhesive.awscli.settings;
  };

  home.packages = [
    pkgs.ssm-session-manager-plugin
  ];
}
