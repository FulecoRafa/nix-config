{ inputs, root, config, ... }:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager.useGlobalPkgs = true;

  home-manager.users.fuleco = {pkgs, rootPath, ...}: {
    programs.home-manager.enable = true;

    imports =  [
      (root + /termapps/fastfetch)
    ];

    home.stateVersion = config.system.stateVersion;
    
    home.packages = with pkgs; [
    ];
  };
}
