{ pkgs, ... }:
let
  catppuccin = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "catppuccin";
    version = "unstable-2024-12-08";
    src = pkgs.fetchFromGitHub {
      owner = "catppuccin";
      repo = "tmux";
      rev = "v2.1.2";
      sha256 = "sha256-vBYBvZrMGLpMU059a+Z4SEekWdQD0GrDqBQyqfkEHPg=";
    };
  };
in
{
  programs.tmux = {
    enable = true;

    aggressiveResize = true;
    baseIndex = 1;
    clock24 = true;
    customPaneNavigationAndResize = true;
    disableConfirmationPrompt = true;
    keyMode = "vi";
    mouse = true;
    newSession = true;
    secureSocket = true;
    sensibleOnTop = true;
    shell = "${pkgs.nushell}/bin/nu";
    prefix = "C-Space";
    terminal = "screen-256color";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-strategy-nvim 'session'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
        '';
      }
      vim-tmux-navigator
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavour 'mocha'
          set -g @catppuccin_window_status_style 'rounded'
        '';
      }
    ];

    extraConfig = ''
      set-option -sa terminal-overrides ",xterm*:Tc"

      # Extra base index settings
      set-window-option -g pane-base-index 1
      set-option -g renumber-windows on

      # Status bar
      set -g status-right-length 100
      set -g status-left-length 100
      set -g status-left ""
      set -g status-right "#{E:@catppuccin_status_application}"
      set -ag status-right "#{E:@catppuccin_status_session}"

      # Shift arrow to switch windows
      bind -n S-Left  previous-window
      bind -n S-Right next-window

      # Shift Alt vim keys to switch windows
      bind -n M-H previous-window
      bind -n M-L next-window

      # Selection keybindings
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      # Open in current working directory
      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      TMUX_SESSIONIZER="~/.local/bin/tmux-sessionizer.nu"
      NUSHELL_WITH_ENV="nu --env-config ~/.config/nushell/env.nu --commands"
      WIDTH="100%"
      HEIGHT="100%"
      TMUX_SESSIONIZER_KEY="f"

      TMUX_SESSIONIZER_PREFIX="prefix_$TMUX_SESSIONIZER_KEY"
      bind-key -T prefix $TMUX_SESSIONIZER_KEY switch-client -T $TMUX_SESSIONIZER_PREFIX

      bind-key -r -T $TMUX_SESSIONIZER_PREFIX h display-popup -EE -w $WIDTH -h $HEIGHT "$NUSHELL_WITH_ENV '\
          use nu-git-manager *;\
          $TMUX_SESSIONIZER ...(gm list --full-path) --short\
      '"
      bind-key -r -T $TMUX_SESSIONIZER_PREFIX n run-shell "$TMUX_SESSIONIZER new-session"
      bind-key -r -T $TMUX_SESSIONIZER_PREFIX s display-popup -EE -w $WIDTH -h $HEIGHT "$TMUX_SESSIONIZER switch-session"
      bind-key -r -T $TMUX_SESSIONIZER_PREFIX r display-popup -EE -w $WIDTH -h $HEIGHT "$TMUX_SESSIONIZER remove-sessions"
      bind-key -r -T $TMUX_SESSIONIZER_PREFIX % run-shell "$TMUX_SESSIONIZER alternate"
      bind-key -r -T $TMUX_SESSIONIZER_PREFIX e display-popup -EE -w $WIDTH -h $HEIGHT "$NUSHELL_WITH_ENV '\
          $TMUX_SESSIONIZER harpoon edit\
      '"
      bind-key -r -T $TMUX_SESSIONIZER_PREFIX j display-popup -EE -w $WIDTH -h $HEIGHT "$TMUX_SESSIONIZER harpoon entries"
      bind-key -r -T $TMUX_SESSIONIZER_PREFIX a run-shell "$TMUX_SESSIONIZER harpoon add"
      bind-key -r -T $TMUX_SESSIONIZER_PREFIX 1 run-shell "$TMUX_SESSIONIZER harpoon jump 0"
      bind-key -r -T $TMUX_SESSIONIZER_PREFIX 2 run-shell "$TMUX_SESSIONIZER harpoon jump 1"
      bind-key -r -T $TMUX_SESSIONIZER_PREFIX 3 run-shell "$TMUX_SESSIONIZER harpoon jump 2"
      bind-key -r -T $TMUX_SESSIONIZER_PREFIX 4 run-shell "$TMUX_SESSIONIZER harpoon jump 3"
    '';
  };
}
