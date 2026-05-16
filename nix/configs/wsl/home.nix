{ user, ... }:
{
  home.homeDirectory = "/home/${user}";

  services.ssh-agent.enable = true;

  imports = [
    ./pkgs
  ];
}
