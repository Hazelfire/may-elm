{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  name = "MayShell";
  buildInputs = with pkgs; [nodePackages.yarn awscli tmuxp];
}
