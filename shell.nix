{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  name = "MayShell";
  buildInputs = with pkgs; [
    nodePackages.yarn 
    awscli 
    tmuxp
    elmPackages.elm
    elmPackages.elm-format
    elm2nix
  ];
}
