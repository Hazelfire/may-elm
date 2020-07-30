{ pkgs ? import <nixpkgs> {} }:
let 
  elmProject = (import ./elm.nix {});
in
pkgs.stdenv.mkDerivation {
  name = "mayfront";
  buildInputs = [ elmProject ];
  src = ./.;
  installPhase = ''
    mkdir $out
    cp -r static/* $out
    cp ${elmProject}/TodoList.min.js $out/main.js
  '';
  }


