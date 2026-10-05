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
    # O hyprlock (Home Manager) autentica a senha por esta pilha; a digital
    # ele lê direto do fprintd, em paralelo, então o pam_fprintd fica de fora.
    pam.services.hyprlock = {
      fprintAuth = false;
      # Senha errada volta na hora, sem o atraso de 2 s do pam_unix.
      nodelay = true;
    };
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
