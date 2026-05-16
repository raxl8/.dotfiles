{
  pkgs,
  user,
  ...
}:
{
  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = ''
      experimental-features = nix-command flakes ca-derivations
    '';
    gc.automatic = true;
  };

  users.users.${user} = {
    shell = pkgs.zsh;
  };
}
