{ ... }:
{
  programs.zsh.envExtra = ''
    export DYLD_FALLBACK_LIBRARY_PATH="/opt/homebrew/lib:$DYLD_FALLBACK_LIBRARY_PATH"
    export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
  '';
}
