{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  name = "MayShell";
  buildInputs = with pkgs; [
    nodePackages.yarn 
    tmuxp
    elmPackages.elm
    elmPackages.elm-format
    chromium
    elm2nix
  ];
}
