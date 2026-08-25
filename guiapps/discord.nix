{ lib, pkgs, ... }:

let
  supported = pkgs.stdenv.hostPlatform.isx86_64;
in
{
  # O pacote oficial desabilita o updater interno e habilita Ozone/Wayland
  # quando NIXOS_OZONE_WL e WAYLAND_DISPLAY estão presentes.
  home.packages = lib.optionals supported [ pkgs.discord ];

  warnings = lib.optional (!supported) ''
    Discord não foi instalado em ${pkgs.stdenv.hostPlatform.system}: o cliente
    Linux oficial distribuído pelo nixpkgs suporta somente x86_64.
  '';
}
