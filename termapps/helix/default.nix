{ pkgs, inputs, ... }:

{
  programs.helix = {
    enable = true;
    package = inputs.helix.packages.${pkgs.system}.helix;
  }
}
