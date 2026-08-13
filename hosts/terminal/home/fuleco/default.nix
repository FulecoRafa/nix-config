{
  inputs,
  root,
  config,
  fulecoLib,
  ...
}:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.extraSpecialArgs = {
    inherit inputs root fulecoLib;
  };

  home-manager.users.fuleco = import ./home-module.nix;
}
