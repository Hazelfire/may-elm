{ pkgs ? import <nixpkgs> { system = "x86_64-linux";} }:                                   
let
  elmProject = import ./elm.nix {};
in
# nixpkgs package set                   
pkgs.dockerTools.buildImage { 
    fromImage = ./alpine.tar.gz;
    # helper to build Docker image          
    name = "elm-may";             
    # give docker image a name              
    tag = "latest";                    
    # provide a tag                         
    contents = (with pkgs; [  
      pixman
      busybox
      nodejs
      bash
      cacert
      pkg-config
      yarn 
      elmPackages.elm
      elmPackages.elm-format
      elm2nix
      python3
      zip
    ]) ++ elmProject.nativeBuildInputs;
}
