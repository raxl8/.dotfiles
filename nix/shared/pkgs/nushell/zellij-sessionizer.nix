{ writeScript }:
# credits: https://github.com/silicakes/zellij-sessionizer/blob/bb9b0f8759748e35c5dfed96fe962ff483760428/zellij-sessionizer.nu
writeScript "zellij-sessionizer.nu" # nu
  ''
    #!/usr/bin/env nu
    def is-inside-zellij [] {
        $env.ZELLIJ? != null
    }

    # attach to a Zellij session by fuzzy finding projects
    #
    # the projects are computed by listing all the directories at depth between 1
    # and 2 recursively under the `path` argument.
    def main [
        path: path  # the directory to search projects inside
    ] {
        let chosen_path = (if (which fd | is-empty) {
            ^find $path -mindepth 1 -maxdepth 1 -type d
        } else {
            ^fd . $path --min-depth 1 --max-depth 1 --type d
        } | fzf)

        if ($chosen_path | is-empty) {
            return
        }

        let session_name = ($chosen_path | path basename)

        if not (is-inside-zellij) {
            zellij attach --create $session_name options --default-cwd $chosen_path
            return
        }

        # first create the session in the background if it doesn't exist
        # creating it through session-switcher will not set the cwd
        let sessions = (zellij list-sessions --no-formatting --short | lines | where $it == $session_name)
        if ($sessions | is-empty) {
            zellij attach $session_name --create-background options --default-cwd $chosen_path
        }

        zellij plugin -c $"session_name=($session_name),dir=($chosen_path)" -- session-switcher
    }
  ''
