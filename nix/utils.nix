{
  inputs,
  self,
  nixpkgs,
  adhesive,
  nix-darwin,
  home-manager,
  nix-homebrew,
  homebrew-core,
  homebrew-cask,
  homebrew-bundle,
}:
let
  mkConfiguration =
    {
      architecture,
      configurationFolder,
      user ? adhesive.user,
      isContainer ? false,
      isDarwin ? false,
    }:
    let
      inherit (pkgs) lib;
      pkgs = import nixpkgs {
        localSystem = architecture;
        config.allowUnfree = true;
      };
      mkSystem = if isDarwin then nix-darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;
      homeManagerModules = if isDarwin then home-manager.darwinModules else home-manager.nixosModules;
    in
    mkSystem {
      pkgs = pkgs;

      system = lib.mkIf isDarwin architecture;

      specialArgs = {
        inherit
          inputs
          adhesive
          user
          isContainer
          ;
      };

      modules = [
        ./shared/host.nix
        "${configurationFolder}/host.nix"

        homeManagerModules.home-manager
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
                ./shared/home.nix
                "${configurationFolder}/home.nix"
              ];
            };
        }
      ]
      ++ (
        if isDarwin then
          [
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                enableRosetta = true;
                user = user;

                taps = {
                  "homebrew/homebrew-core" = homebrew-core;
                  "homebrew/homebrew-cask" = homebrew-cask;
                  "homebrew/homebrew-bundle" = homebrew-bundle;
                };
                # mutableTaps = false;
              };
            }
          ]
        else
          [ ]
      );
    };
in
{
  mkConfiguration = mkConfiguration;
  mkDarwinConfiguration = args: (mkConfiguration (args // { isDarwin = true; }));
}
