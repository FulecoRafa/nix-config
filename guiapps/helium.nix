{ lib, pkgs, ... }:

{
  home.packages = [ (import ./helium/package.nix { inherit lib pkgs; }) ];
}
