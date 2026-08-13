{
  config,
  fulecoLib,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf mkOption types;
  cfg = config.localWebApps;
  helium = import ./helium/package.nix { inherit lib pkgs; };

  mkLauncher =
    id: app:
    fulecoLib.mkWebAppLauncher pkgs {
      inherit id app;
      browser = cfg.browser;
    };

  launchers = lib.mapAttrs mkLauncher cfg.apps;
  desktopFiles = lib.mapAttrs' (
    id: app:
    fulecoLib.mkDesktopEntry {
      id = "local-web-app-${id}";
      inherit (app)
        name
        icon
        comment
        categories
        ;
      exec = lib.getExe launchers.${id};
    }
  ) cfg.apps;
in
{
  options.localWebApps = {
    enable = lib.mkEnableOption "lançadores desktop para interfaces web locais";

    browser = {
      package = mkOption {
        type = types.package;
        default = helium;
        defaultText = lib.literalExpression "Helium empacotado em guiapps/helium";
        description = "Pacote do navegador instalado junto dos lançadores.";
      };
      executable = mkOption {
        type = types.str;
        default = lib.getExe cfg.browser.package;
        defaultText = lib.literalExpression "lib.getExe config.localWebApps.browser.package";
        description = "Caminho do executável do navegador, sem argumentos.";
      };
      arguments = mkOption {
        type = types.listOf types.str;
        default = [
          "--app={{url}}"
          "--ozone-platform-hint=auto"
        ];
        description = "Argumentos do navegador; {{url}} é substituído pela URL do app.";
      };
    };

    apps = mkOption {
      default = { };
      description = "Aplicações web registradas no launcher.";
      type = types.attrsOf fulecoLib.types.webApp;
      example = lib.literalExpression ''
        {
          meu-app = fulecoLib.mkWebApp "Meu App" {
            url = "http://127.0.0.1:8080";
            service = "meu-app.service";
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.browser.package ] ++ builtins.attrValues launchers;

    # Gerado diretamente porque esta revisão usa Home Manager 25.11 com
    # nixpkgs 26.11, combinação em que xdg.desktopEntries chama uma opção
    # removida do makeDesktopItem.
    xdg.dataFile = desktopFiles;
  };
}
