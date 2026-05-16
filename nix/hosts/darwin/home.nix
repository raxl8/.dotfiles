{ lib, ... }:
{
  xdg.enable = true;

  home.activation = {
    link-nushell-config = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ln -sf $HOME/.config/nushell $HOME/Library/Application\ Support/nushell
    '';
  };

  imports = [
    ./pkgs
  ];
}
