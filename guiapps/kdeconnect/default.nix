{ pkgs, ... }:
let
  kdeconnect = pkgs.kdePackages.kdeconnect-kde;
in
{
  # Hyprland/UWSM não fornece o autostart do Plasma. Manter o daemon ligado à
  # sessão gráfica garante clipboard, notificações e descoberta em background.
  systemd.user.services.kdeconnect = {
    Unit = {
      Description = "KDE Connect device synchronization";
      Documentation = [ "https://kdeconnect.kde.org/" ];
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${kdeconnect}/libexec/kdeconnectd";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
