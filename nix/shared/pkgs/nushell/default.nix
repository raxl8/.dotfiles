{ config, lib, pkgs, ... }:
let
  # credits: https://github.com/jaredmontoya/home-manager/commit/0b2179ce3e2627380fcf0d4db3f05c1182d56474
  hmSessionVars = pkgs.runCommand "hm-session-vars.nu" { } ''
    echo "if ('__HM_SESS_VARS_SOURCED' not-in \$env) {$(${
      lib.getExe pkgs.nushell
    } -c "
      source ${pkgs.callPackage ./capture-foreign-env.nix { }}
      open ${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh | capture-foreign-env | to nuon
    ") | load-env}" >> "$out"
  '';
in
{
  programs.nushell = {
    enable = true;

    extraLogin = ''
      source ${hmSessionVars}
    '';

    extraConfig = ''
      $env.config = {
        show_banner: false
        edit_mode: vi
        keybindings: [
          {
            name: zellij_sessionizer
            modifier: control
            keycode: char_f
            mode: [emacs, vi_insert, vi_normal]
            event: {
              send: executehostcommand
              cmd: "${pkgs.callPackage ./zellij-sessionizer.nix { }} $env.GIT_REPOS_HOME"
            }
          }
        ]
      }
    '';

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
    };

    extraEnv = ''
      use std "path add"
      # Local bin
      path add $"($env.HOME | path join ".local/bin")"

      # ssh-agent
      do --env {
          let ssh_agent_file = (
              $nu.temp-path | path join $"ssh-agent-($env.USER).nuon"
          )

          if ($ssh_agent_file | path exists) {
              let ssh_agent_env = open ($ssh_agent_file)
              if ($"/proc/($ssh_agent_env.SSH_AGENT_PID)" | path exists) {
                  load-env $ssh_agent_env
                  return
              } else {
                  rm $ssh_agent_file
              }
          }

          let ssh_agent_env = ^ssh-agent -c
              | lines
              | first 2
              | parse "setenv {name} {value};"
              | transpose --header-row
              | into record
          load-env $ssh_agent_env
          $ssh_agent_env | save --force $ssh_agent_file
      }

      # Add keys to ssh-agent
      use std
      try { ^ssh-add o+e> (std null-device) }
    '';

    environmentVariables = {
      GIT_REPOS_HOME = "${config.home.homeDirectory}/git";
    };
  };
}
