{ pkgs, ... }:
let
  kdeconnect = pkgs.kdePackages.kdeconnect-kde;
in
{
  # O módulo instala a aplicação Qt e abre TCP/UDP 1714–1764, usados para
  # descoberta, pareamento e comunicação entre dispositivos.
  programs.kdeconnect = {
    enable = true;
    package = kdeconnect;
  };
}
