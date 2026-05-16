{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    systems.url = "github:nix-systems/default";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

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

    ghostty = {
      url = "github:ghostty-org/ghostty";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      adhesive,
      nix-darwin,
      home-manager,
      nix-homebrew,
      homebrew-core,
      homebrew-cask,
      homebrew-bundle,
      ...
    }:
    let
      utils = import ./nix/utils.nix {
        inherit
          inputs
          self
          nixpkgs
          adhesive
          nix-darwin
          home-manager
          nix-homebrew
          homebrew-core
          homebrew-cask
          homebrew-bundle
          ;
      };
    in
    {
      nixosConfigurations = {
        wsl = utils.mkConfiguration {
          architecture = "x86_64-linux";
          configurationFolder = ./nix/configs/wsl;
          isContainer = true;
        };
      };
      darwinConfigurations = {
        darwin = utils.mkDarwinConfiguration {
          architecture = "aarch64-darwin";
          configurationFolder = ./nix/configs/darwin;
        };
      };
    };
}
