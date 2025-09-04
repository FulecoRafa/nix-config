{ inputs, root, config, ... }:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.extraSpecialArgs = { inherit inputs; inherit root; };

  home-manager.users.fuleco = import ./home-module.nix;
}
