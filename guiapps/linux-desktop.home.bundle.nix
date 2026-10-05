{
  pkgs,
  root,
  ...
}:

# Aplicações e configuração da sessão gráfica Linux.
{
  imports = [
    ./default.nix
    ./discord.nix
    ./hyprland
    ./kdeconnect
    (root + /termapps/ai-usage)
    (root + /services/flatpak-lab)
    (root + /services/live-config)
  ];

  services.liveConfig.enable = true;

  home.packages = with pkgs; [
    obs-studio
    vscode
    zed-editor
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/pdf" = [ "helium.desktop" ];
      "text/html" = [ "helium.desktop" ];
      "x-scheme-handler/http" = [ "helium.desktop" ];
      "x-scheme-handler/https" = [ "helium.desktop" ];
      "video/mp4" = [ "mpv.desktop" ];
      "video/webm" = [ "mpv.desktop" ];
      "image/jpeg" = [ "imv.desktop" ];
      "image/png" = [ "imv.desktop" ];
      "image/webp" = [ "imv.desktop" ];
    };
  };
}
