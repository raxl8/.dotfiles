{ pkgs, ... }:
{
  home.packages = with pkgs; [
    aws-vault
  ];
}
