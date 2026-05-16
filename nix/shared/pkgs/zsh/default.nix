{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;

    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      v = "nvim";
      g = "git";
      ga = "git add";
      gaa = "git add --all";
      gap = "git add --patch";
      gc = "git commit";
      gca = "git commit --amend";
      gco = "git checkout";
      gcom = "git checkout main";
      gcb = "git checkout -b";
      gb = "git branch";
      gba = "git branch -a";
      gbd = "git branch -d";
      gbD = "git branch -D";
      gcount = "git shortlog -sn";
      gd = "git diff";
      gdc = "git diff --cached";
      gdt = "git difftool";
      gg = "git log --oneline --graph --decorate";
      gga = "git log --oneline --graph --decorate --all";
      ggag = "git log --oneline --graph --decorate --all --grep";
      ggagp = "git log --oneline --graph --decorate --all --grep --pickaxe-all";
      ggb = "git log --oneline --graph --decorate --branches";
      ggc = "git log --oneline --graph --decorate --date=short --pretty=format:\"%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %C(bold blue)<%an>%Creset\" --abbrev-commit";
      ggcA = "git log --oneline --graph --decorate --date=short --pretty=format:\"%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %C(bold blue)<%an>%Creset\" --abbrev-commit --all";
      gs = "git status";
      gss = "git status -s";
      gsw = "git status -sb";
      gl = "git pull";
      gu = "git push";
      guu = "git push --set-upstream origin (git rev-parse --abbrev-ref HEAD)";
      lg = "lazygit";
      claude-perso = "CLAUDE_CONFIG_DIR=~/.claude-perso claude";
      claude-work = "CLAUDE_CONFIG_DIR=~/.claude-work claude";
      ffmpeg = "ffmpeg -hide_banner";
      ffprobe = "ffprobe -hide_banner";
    };

    dotDir = "${config.xdg.configHome}/zsh";

    # defaultKeymap = "vicmd";
    #
    autosuggestion.enable = true;

    sessionVariables = {
      GIT_REPOS_HOME = "${config.home.homeDirectory}/git";
      PATH = "${config.home.homeDirectory}/.local/bin:$PATH";
    };

    initContent = ''
      zellij_sessionizer_widget() {
          ${pkgs.callPackage ./zellij-sessionizer.nix { }} $GIT_REPOS_HOME
      }

      zle -N zellij_sessionizer_widget

      bindkey "^F" "zellij_sessionizer_widget"
    '';
  };
}
