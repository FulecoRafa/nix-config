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
      ./userdata.nix
    ];

    userdata = {
      name = "FulecoRafa";
      email = "ra.pha@live.com";
    };

    home.sessionVariables = {
      EDITOR = "hx";
      COLORTERM = "truecolor";
    };

    home.stateVersion = config.system.stateVersion;
    
    home.packages = with pkgs; [
    ];

    programs.helix.defaultEditor = true;
  };
}
