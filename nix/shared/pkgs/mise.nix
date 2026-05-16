{ config, ... }:
{
  programs.mise.enable = true;

  programs.mise.enableZshIntegration = true;

  programs.mise.enableNushellIntegration = true;

  programs.nushell.extraEnv = ''
    let mise_cache = "${config.xdg.cacheHome}/mise"
    if not ($mise_cache | path exists) {
      mkdir $mise_cache
    }
    ${config.programs.mise.package}/bin/mise activate nu | save --force ${config.xdg.cacheHome}/mise/init.nu
  '';

  programs.nushell.extraConfig = ''
    use ${config.xdg.cacheHome}/mise/init.nu
  '';

  home.sessionVariables = {
    GOPATH = "${config.home.homeDirectory}/.go";
  };
}
