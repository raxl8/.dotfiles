{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    adhesive.url = "git+ssh://git@github.com/raxl8/.dotfiles-adhesive.git?ref=main";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      hostLib = import ./nix/lib/hosts.nix {
        inherit inputs self;
      };

      hosts = {
        wsl = {
          kind = "nixos";
          system = "x86_64-linux";
          path = ./nix/hosts/wsl;
          isContainer = true;
        };

        darwin = {
          kind = "darwin";
          system = "aarch64-darwin";
          path = ./nix/hosts/darwin;
        };
      };

      mkConfigurations =
        kind:
        lib.mapAttrs (_: host: hostLib.mkHost host) (lib.filterAttrs (_: host: host.kind == kind) hosts);
    in
    {
      nixosConfigurations = mkConfigurations "nixos";
      darwinConfigurations = mkConfigurations "darwin";
    };
}
