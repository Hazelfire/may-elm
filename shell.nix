{ pkgs ? import <nixpkgs> {} }:
let
  elmProject = import ./elm.nix {};
in
pkgs.mkShell {
  name = "MayShell";
  buildInputs = (with pkgs; [
    nodePackages.yarn 
    tmuxp
    elmPackages.elm
    elmPackages.elm-format
    chromium
    elm2nix
    elmProject.nativeBuildInputs
    closurecompiler
    libuuid
  ]);
}
