{ inputs, root, config, ... }:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.extraSpecialArgs = { inherit inputs; };

  home-manager.users.fuleco = {pkgs, ...}: {
    programs.home-manager.enable = true;

    imports =  [
      (root + /termapps/cli_utils.bundle.nix)
      (root + /termapps/nushell)
    ];

    home.stateVersion = config.system.stateVersion;
    
    home.packages = with pkgs; [
    ];
  };
}
