{ lib, pkgs, ... }:
{
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = lib.concatStringsSep " " [
        (lib.getExe pkgs.tuigreet)
        "--time"
        "--remember"
        "--remember-user-session"
        "--asterisks"
        "--sessions /run/current-system/sw/share/wayland-sessions"
        "--cmd '${lib.getExe pkgs.uwsm} start hyprland-uwsm.desktop'"
      ];
      user = "greeter";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/cache/tuigreet 0755 greeter greeter -"
  ];

  environment.systemPackages = [ pkgs.tuigreet ];
}
