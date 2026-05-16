{ inputs, self }:
let
  inherit (inputs)
    adhesive
    home-manager
    homebrew-bundle
    homebrew-cask
    homebrew-core
    nix-darwin
    nix-homebrew
    nixpkgs
    ;

  mkHost =
    {
      kind,
      system,
      path,
      user ? adhesive.user,
      isContainer ? false,
    }:
    let
      inherit (nixpkgs) lib;

      isDarwin = kind == "darwin";
      pkgs = import nixpkgs {
        localSystem = system;
        config.allowUnfree = true;
      };
      mkSystem = if isDarwin then nix-darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;
      homeManagerModule =
        if isDarwin then
          home-manager.darwinModules.home-manager
        else
          home-manager.nixosModules.home-manager;
    in
    mkSystem {
      inherit pkgs system;

      specialArgs = {
        inherit
          inputs
          adhesive
          user
          isContainer
          ;
      };

      modules = [
        ../shared/host.nix
        (path + /host.nix)

        homeManagerModule
        {
          home-manager.useGlobalPkgs = false;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit
              inputs
              self
              adhesive
              user
              ;
          };
          home-manager.users."${user}" =
            { ... }:
            {
              nixpkgs.config.allowUnfree = true; # remove when aws-sam-cli overlays are not needed anymore
              imports = [
                ../shared/home.nix
                (path + /home.nix)
              ];
            };
        }
      ]
      ++ lib.optionals isDarwin [
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            inherit user;

            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
              "homebrew/homebrew-bundle" = homebrew-bundle;
            };
          };
        }
      ];
    };
in
{
  inherit mkHost;
}
