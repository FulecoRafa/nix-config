{ pkgs, inputs, ... }:

{
  users.users.fuleco.packages = [
    inputs.helix.packages.${pkgs.system}.helix
  ];
}
