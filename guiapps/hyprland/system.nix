{ ... }:

# Base NixOS compartilhável para desktops Hyprland iniciados pelo UWSM.
{
  imports = [ ./login.nix ];

  hardware.graphics.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  security = {
    polkit.enable = true;
    rtkit.enable = true;
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "Hyprland";
  };
}
