{ pkgs, ... }:
{
  home.packages = with pkgs; [
    bacon
    cargo-autoinherit
    cargo-llvm-cov
    cargo-udeps
    rustlings
    starship-jj
    watchexec
  ];
}
