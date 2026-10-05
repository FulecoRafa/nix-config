{ root, ... }:

# Serviços NixOS compartilhados pelos desktops Linux desta configuração.
{
  imports = [
    ./espanso/system.nix
    ./hyprland/system.nix
    ./kdeconnect/system.nix
    ./steam/system.nix
    (root + /services/flatpak-lab/system.nix)
    (root + /services/tailscale-client/system.nix)
  ];

  hardware.bluetooth.enable = true;
}
