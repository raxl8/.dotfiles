{ adhesive, ... }:
{
  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = adhesive.jujutsu.name;
        email = adhesive.jujutsu.email;
      };
      ui = {
        default-command = "log";
      };
      signing = {
        behavior = "own";
        backend = "ssh";
        key = adhesive.jujutsu.signingKey;
      };
      git = {
        sign-on-push = true;
      };
    };
  };
}
