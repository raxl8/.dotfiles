{ ... }:
{
  programs.zoxide.enable = true;

  programs.zoxide.enableNushellIntegration = true;

  programs.zoxide.options = [ "--cmd=cd" ];
}
