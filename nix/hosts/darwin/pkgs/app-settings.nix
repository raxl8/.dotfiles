{ config, lib, ... }:
let
  dotfiles = "${config.home.homeDirectory}/git/.dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  home.activation.install-vscode-extensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v code >/dev/null 2>&1; then
      while IFS= read -r extension; do
        [ -n "$extension" ] && run code --install-extension "$extension" --force
      done < "${dotfiles}/.config/vscode/extensions.txt"
    fi
  '';

  home.file = {
    ".finicky.js" = {
      source = link ".finicky.js";
      force = true;
    };

    ".config/karabiner/karabiner.json" = {
      source = link ".config/karabiner/karabiner.json";
      force = true;
    };

    ".agents/skills" = {
      source = link ".agents/skills";
      force = true;
    };

    ".codex/AGENTS.md" = {
      source = link ".codex/AGENTS.md";
      force = true;
    };

    ".codex/config.toml" = {
      source = link ".codex/config.toml";
      force = true;
    };

    ".codex/skills/frontend-design" = {
      source = link ".agents/skills/frontend-design";
      force = true;
    };

    ".codex/skills/pdf" = {
      source = link ".agents/skills/pdf";
      force = true;
    };

    ".codex/skills/vercel-composition-patterns" = {
      source = link ".agents/skills/vercel-composition-patterns";
      force = true;
    };

    ".codex/skills/vercel-react-best-practices" = {
      source = link ".agents/skills/vercel-react-best-practices";
      force = true;
    };

    ".claude/settings.json" = {
      source = link ".claude/settings.json";
      force = true;
    };

    "Library/Application Support/Claude/claude_desktop_config.json" = {
      source = link ".config/claude-desktop/claude_desktop_config.json";
      force = true;
    };

    "Library/Application Support/Claude/developer_settings.json" = {
      source = link ".config/claude-desktop/developer_settings.json";
      force = true;
    };

    "Library/Application Support/Code/User/keybindings.json" = {
      source = link ".config/vscode/keybindings.json";
      force = true;
    };

    "Library/Application Support/Code/User/settings.json" = {
      source = link ".config/vscode/settings.json";
      force = true;
    };
  };
}
