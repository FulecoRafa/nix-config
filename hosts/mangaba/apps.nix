{ config, lib, ... }:

# Apps: Vaultwarden, Forgejo, ntfy, Actual Budget, Karakeep.
# Todos com módulo nativo — nenhum precisou virar container.
let
  fqdn = config.mangaba.tailscale.fqdn;
  cfg = config.mangaba.apps;

  ports = {
    vaultwarden = 8222;
    forgejo = 3000;
    ntfy = 8095;
    actual = 5006;
    karakeep = 3010;
  };

  url = port: "https://${fqdn}:${toString port}";
in
{
  options.mangaba.apps.karakeep.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Karakeep passa de 400MB com o Meilisearch junto, mesmo sem ML — é o app
      mais caro proporcionalmente ao valor num orçamento de 8GB. Ligar só
      depois de medir a folga de RAM.

      Hoje o build também puxa `pnpm-9.15.9`, marcado como inseguro no
      nixpkgs, então ligar isto exige também:
        nixpkgs.config.permittedInsecurePackages = [ "pnpm-9.15.9" ];
    '';
  };

  config = {
    # --- Vaultwarden -------------------------------------------------------
    services.vaultwarden = {
      enable = true;
      dbBackend = "sqlite";
      config = {
        DOMAIN = url ports.vaultwarden;
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = ports.vaultwarden;
        # Deixar aberto até criar a própria conta, depois virar false.
        SIGNUPS_ALLOWED = true;
        WEBSOCKET_ENABLED = true;
      };
    };

    # --- Forgejo -----------------------------------------------------------
    services.forgejo = {
      enable = true;
      database.type = "sqlite3";
      lfs.enable = true;
      settings = {
        server = {
          DOMAIN = fqdn;
          ROOT_URL = "${url ports.forgejo}/";
          HTTP_ADDR = "127.0.0.1";
          HTTP_PORT = ports.forgejo;
        };
        service.DISABLE_REGISTRATION = true;
        # Instância de uma pessoa só: sem mirror automático nem gravatar.
        picture.DISABLE_GRAVATAR = true;
      };
    };

    # --- ntfy --------------------------------------------------------------
    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = url ports.ntfy;
        listen-http = "127.0.0.1:${toString ports.ntfy}";
        behind-proxy = true;
        auth-default-access = "deny-all";
      };
    };

    # --- Actual Budget -----------------------------------------------------
    services.actual = {
      enable = true;
      settings = {
        hostname = "127.0.0.1";
        port = ports.actual;
      };
    };

    # --- Karakeep ----------------------------------------------------------
    services.karakeep = lib.mkIf cfg.karakeep.enable {
      enable = true;
      # NEXTAUTH_SECRET e MEILI_MASTER_KEY não podem ir para o nix store.
      environmentFile = config.mangaba.secrets.path "karakeep/env";
      extraEnvironment = {
        PORT = toString ports.karakeep;
        NEXTAUTH_URL = url ports.karakeep;
        DISABLE_SIGNUPS = "true";
        # Sem inferência: não há GPU e a RAM é o gargalo.
        INFERENCE_TEXT_MODEL = "";
      };
      # O crawler headless é o que mais pesa; deixar de fora.
      browser.enable = false;
    };

    assertions = [
      {
        assertion = cfg.karakeep.enable -> config.mangaba.secrets.enable;
        message = "mangaba.apps.karakeep.enable exige mangaba.secrets.enable (NEXTAUTH_SECRET).";
      }
    ];

    mangaba.secrets.declare = lib.mkIf (config.mangaba.secrets.enable && cfg.karakeep.enable) {
      "karakeep/env" = {
        restartUnits = [ "karakeep.service" ];
      };
    };

    # Sincronização entre máquinas: ver sync.nix (rsync num timer de 15min).

    # --- Publicação no tailnet --------------------------------------------
    mangaba.tailscale.serve = {
      vaultwarden = {
        port = ports.vaultwarden;
        target = "http://127.0.0.1:${toString ports.vaultwarden}";
        title = "Vaultwarden";
        description = "Cofre de senhas (compatível com Bitwarden).";
        category = "Apps";
        icon = "di:vaultwarden";
      };
      forgejo = {
        port = ports.forgejo;
        target = "http://127.0.0.1:${toString ports.forgejo}";
        title = "Forgejo";
        description = "Repositórios git próprios.";
        category = "Apps";
        icon = "di:forgejo";
      };
      ntfy = {
        port = ports.ntfy;
        target = "http://127.0.0.1:${toString ports.ntfy}";
        title = "ntfy";
        description = "Notificações push dos serviços para o celular.";
        category = "Apps";
        icon = "di:ntfy";
      };
      actual = {
        port = ports.actual;
        target = "http://127.0.0.1:${toString ports.actual}";
        title = "Actual Budget";
        description = "Orçamento pessoal.";
        category = "Apps";
        icon = "di:actual-budget";
      };
    }
    // lib.optionalAttrs cfg.karakeep.enable {
      karakeep = {
        port = ports.karakeep;
        target = "http://127.0.0.1:${toString ports.karakeep}";
        title = "Karakeep";
        description = "Bookmarks com busca full-text.";
        category = "Apps";
        icon = "di:karakeep";
      };
    };
  };
}
