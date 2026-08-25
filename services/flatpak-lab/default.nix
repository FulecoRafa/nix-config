{
  lib,
  pkgs,
  ...
}:

let
  cleanup = pkgs.writeShellApplication {
    name = "flatpak-lab-cleanup";
    runtimeInputs = [ pkgs.flatpak ];
    text = builtins.readFile ./cleanup;
  };

  appTry = pkgs.writeShellApplication {
    name = "app-try";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.flatpak
      pkgs.gawk
    ];
    text = ''
      export FLATPAK_LAB_CLEANUP=${lib.escapeShellArg (lib.getExe cleanup)}
      ${builtins.readFile ./app-try}
    '';
  };
in
{
  home.packages = [
    appTry
    cleanup
  ];

  # Se a máquina desligar ou o helper for morto à força, os marcadores
  # sobrevivem e esta unidade termina a limpeza no próximo login.
  systemd.user.services.flatpak-lab-cleanup = {
    Unit = {
      Description = "Remove interrupted Flatpak Lab experiments";
      Documentation = [ "https://docs.flatpak.org/en/latest/using-flatpak.html" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe cleanup;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Um .flatpakref baixado do Flathub abre como experimento em um terminal.
  xdg.desktopEntries.flatpak-lab = {
    name = "Experimentar aplicativo Flatpak";
    comment = "Executa temporariamente um aplicativo e o remove ao fechar";
    exec = "${lib.getExe pkgs.ghostty} -e ${lib.getExe appTry} %f";
    icon = "system-software-install";
    mimeType = [ "application/vnd.flatpak.ref" ];
    categories = [ "System" ];
    terminal = false;
    noDisplay = true;
  };

  xdg.mimeApps.associations.added."application/vnd.flatpak.ref" = [ "flatpak-lab.desktop" ];
}
