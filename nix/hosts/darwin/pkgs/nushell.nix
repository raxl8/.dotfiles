{ ... }:
{
  programs.nushell.extraEnv = ''
    $env.PATH = [
        "/opt/homebrew/bin"
    ] ++ $env.PATH | uniq
  '';
}
