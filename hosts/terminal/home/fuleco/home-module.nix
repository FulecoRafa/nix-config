{pkgs, root, ...}: {
  programs.home-manager.enable = true;

  imports =  [
    (root + /termapps/cli_utils.bundle.nix)
    (root + /termapps/zsh)
    (root + /guiapps/espanso)
    ./userdata.nix
  ];

  userdata = {
    name = "FulecoRafa";
    email = "ra.pha@live.com";
  };

  home.username = "fuleco";
  home.homeDirectory = "/home/fuleco";
  home.sessionVariables = {
    EDITOR = "hx";
    COLORTERM = "truecolor";
  };

  # home.stateVersion = config.system.stateVersion;
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
  ];

  programs.helix.defaultEditor = true;
}
