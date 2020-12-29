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
      busybox
      nodejs
      bash
      cacert
      yarn 
      elmPackages.elm
      elmPackages.elm-format
      elm2nix
      zip
    ]) ++ elmProject.nativeBuildInputs;
}
