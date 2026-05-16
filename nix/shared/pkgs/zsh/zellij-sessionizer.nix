{ writeScript }:
writeScript "zellij-sessionizer.zsh" ''
  is_inside_zellij() {
      [[ -n "''${ZELLIJ-}" ]]
  }

  # attach to a Zellij session by fuzzy finding projects
  #
  # the projects are computed by listing all the directories at depth between 1
  # and 2 recursively under the `path` argument.
  main() {
      local path="$1"
      local chosen_path

      if command -v fd >/dev/null 2>&1; then
          chosen_path=$(fd . "$path" --min-depth 1 --max-depth 1 --type d | fzf)
      else
          chosen_path=$(find "$path" -mindepth 1 -maxdepth 1 -type d | fzf)
      fi

      if [[ -z "$chosen_path" ]]; then
          return 0
      fi

      local session_name
      session_name="$(basename "$chosen_path")"

      if ! is_inside_zellij; then
          zellij attach --create "$session_name" options --default-cwd "$chosen_path"
          return 0
      fi

      # first create the session in the background if it doesn't exist
      # creating it through session-switcher will not set the cwd
      local sessions
      sessions="$(zellij list-sessions --no-formatting --short | grep -Fx "$session_name" || true)"

      if [[ -z "$sessions" ]]; then
          zellij attach "$session_name" --create-background options --default-cwd "$chosen_path"
      fi

      zellij plugin -c "session_name=''${session_name},dir=''${chosen_path}" -- session-switcher
  }

  main "$@"
''
