{
  root,
  ...
}:

{
  imports = [
    (root + /guiapps/linux-desktop.home.bundle.nix)
    (root + /termapps/cli_utils.bundle.nix)
    (root + /termapps/nushell)
    (root + /hosts/terminal/home/fuleco/userdata.nix)
  ];

  userdata = {
    name = "FulecoRafa";
    email = "ra.pha@live.com";
  };

  hyprlandDesktop.workspaceCount = 6;

  home = {
    username = "fuleco";
    homeDirectory = "/home/fuleco";
    stateVersion = "25.05";
    enableNixpkgsReleaseCheck = false;
    sessionVariables = {
      COLORTERM = "truecolor";
      EDITOR = "hx";
    };
  };

  programs = {
    helix.defaultEditor = true;
    home-manager.enable = true;
  };
}
