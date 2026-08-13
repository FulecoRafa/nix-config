{ inputs, pkgs, ... }:

{
  home.packages = [ inputs.fuchico.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}
