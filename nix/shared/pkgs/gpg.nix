{ ... }:
{
  programs.gpg.enable = true;

  # PGP settings for headless pinentry
  home.file.".gnupg/gpg-agent.conf".text = ''
    default-cache-ttl 34560000
    max-cache-ttl 34560000
    allow-loopback-pinentry'';

  programs.gpg.settings = {
    pinentry-mode = "loopback";
  };
}
