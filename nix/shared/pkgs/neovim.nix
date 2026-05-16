{ config, ... }:
let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  xdg.configFile.nvim.source = mkOutOfStoreSymlink "${config.home.homeDirectory}/git/.dotfiles/.config/nvim";

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
    withRuby = false;
    withPython3 = false;
    sideloadInitLua = true;
  };
}
