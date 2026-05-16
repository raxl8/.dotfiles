{ pkgs, ... }:
{
  home.packages = [
    #    pkgs.aws-sam-cli
    pkgs.ssm-session-manager-plugin
  ];
}
