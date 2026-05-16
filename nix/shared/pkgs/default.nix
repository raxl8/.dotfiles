{ ... }:
{
  imports = [
    ./aws-sam-cli.nix
    ./aws-vault.nix
    ./awscli.nix
    ./bun.nix
    ./carapace.nix
    # ./codex.nix
    ./fastfetch.nix
    ./gh.nix
    ./git.nix
    ./gpg.nix
    ./granted.nix
    ./jujutsu.nix
    ./lazygit.nix
    ./mise.nix
    ./neovim.nix
    ./nushell
    ./pipenv.nix
    ./rust-tools.nix
    ./starship.nix
    # ./tmux.nix
    ./uv.nix
    ./zellij
    ./zoxide.nix
    ./zsh
  ];
}
