{ root, ... }:

# Serviços NixOS compartilhados pelos desktops Linux desta configuração.
{
  imports = [
    ./hyprland/system.nix
    ./kdeconnect/system.nix
    ./steam/system.nix
    (root + /services/flatpak-lab/system.nix)
  ];

  hardware.bluetooth.enable = true;
}
