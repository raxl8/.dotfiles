{
  pkgs,
  user,
  ...
}: {
  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (
            python-final: python-prev: {
              pydub = python-prev.pydub.override {
                ffmpeg-full = final.ffmpeg;
              };
            }
          )
        ];
    })
  ];

  home = {
    username = user;
    packages = with pkgs; [
      alejandra
      ffmpeg
      ffsubsync
      fzf
      mediainfo
      mkbrr
      mkvtoolnix-cli
      nixfmt
      ripgrep
      terraform
      unzip
    ];
    stateVersion = "25.05";
  };

  xdg.enable = true;

  imports = [
    ./pkgs
  ];
}
