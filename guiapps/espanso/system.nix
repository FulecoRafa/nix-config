{
  config,
  lib,
  pkgs,
  ...
}:

# No Wayland o Espanso lê o teclado direto dos /dev/input (EVDEV). Em vez de
# pôr o usuário no grupo `input`, um wrapper dá só a capability necessária,
# que o próprio Espanso descarta depois de abrir os dispositivos (mesmo
# esquema do módulo NixOS `services.espanso`). O Home Manager aponta para ele.
{
  security.wrappers.espanso = {
    capabilities = "cap_dac_override+p";
    owner = "root";
    group = "root";
    source = lib.getExe (
      pkgs.espanso-wayland.override { securityWrapperPath = config.security.wrapperDir; }
    );
  };
}
