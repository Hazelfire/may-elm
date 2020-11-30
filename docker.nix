{ pkgs ? import <nixpkgs> { system = "x86_64-linux";} }:                                   
let
  elmProject = import ./elm.nix {};
in
# nixpkgs package set                   
pkgs.dockerTools.buildImage { 
    # helper to build Docker image          
    fromImage = ./alpine.tar.gz;
    name = "elm-may";             
    # give docker image a name              
    tag = "latest";                    
    # provide a tag                         
    contents = (with pkgs; [  
      nodePackages.yarn 
      elmPackages.elm
      elmPackages.elm-format
      elm2nix
      zip
    ]) ++ elmProject.nativeBuildInputs;
}
