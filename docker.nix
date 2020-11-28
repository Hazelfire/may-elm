{ pkgs ? import <nixpkgs> { system = "x86_64-linux";} }:                                   
# nixpkgs package set                   
pkgs.dockerTools.buildLayeredImage { 
    # helper to build Docker image          
    name = "elm-may";             
    # give docker image a name              
    tag = "latest";                    
    # provide a tag                         
    contents = with pkgs; [  
      nodePackages.yarn 
      elmPackages.elm
      elmPackages.elm-format
      elm2nix
    ];         
}
