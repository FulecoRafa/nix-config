{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.gaming;
  supported = pkgs.stdenv.hostPlatform.isx86_64;
in
{
  options.gaming = {
    enable = lib.mkEnableOption "Steam e a base de jogos" // {
      default = true;
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "fuleco";
      description = "Usuário autorizado a usar o GameMode.";
    };
  };

  config = lib.mkMerge [
    {
      warnings = lib.optional (cfg.enable && !supported) ''
        A base Steam está desativada neste sistema porque Steam suporta
        x86_64-linux, não ${pkgs.stdenv.hostPlatform.system}.
      '';
    }

    (lib.mkIf (cfg.enable && supported) {
      programs = {
        steam = {
          enable = true;

          # Corrige o controle do cursor pelo Steam Input em sessões Wayland.
          extest.enable = true;

          # Mantém Proton-GE no catálogo de ferramentas de compatibilidade.
          extraCompatPackages = [ pkgs.proton-ge-bin ];
          protontricks.enable = true;

          # Dependências usadas por overlays, controles e Gamescope dentro do
          # ambiente FHS do Steam.
          extraPackages = with pkgs; [
            gamemode
            hidapi
            keyutils
            libkrb5
            libpng
            libpulseaudio
            libvorbis
            libxcursor
            libxi
            libxinerama
            libxscrnsaver
            mangohud
            stdenv.cc.cc.lib
          ];

          localNetworkGameTransfers.openFirewall = true;
        };

        gamemode = {
          enable = true;
          enableRenice = true;
        };

        gamescope = {
          enable = true;
          capSysNice = true;
        };
      };

      users.users.${cfg.user}.extraGroups = [ "gamemode" ];

      environment.systemPackages = [ pkgs.mangohud ];
    })
  ];
}
