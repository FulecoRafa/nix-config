{ lib }:

{
  webApp = lib.types.submodule (
    { name, config, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Nome exibido no launcher.";
        };

        url = lib.mkOption {
          type = lib.types.str;
          example = "http://127.0.0.1:8080";
          description = "URL aberta em modo aplicação.";
        };

        icon = lib.mkOption {
          type = lib.types.nullOr (lib.types.either lib.types.str lib.types.path);
          default = null;
          description = "Nome ou caminho do ícone.";
        };

        comment = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Descrição exibida pelo launcher.";
        };

        categories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "Utility" ];
          description = "Categorias freedesktop da aplicação.";
        };

        service = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "meu-app.service";
          description = "Serviço systemd de usuário iniciado antes do navegador.";
        };

        healthCheck = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = config.service != null;
            description = "Esperar um endpoint HTTP responder antes de abrir o navegador.";
          };

          url = lib.mkOption {
            type = lib.types.str;
            default = config.url;
            description = "Endpoint HTTP usado para verificar se a aplicação está pronta.";
          };

          timeoutSeconds = lib.mkOption {
            type = lib.types.ints.positive;
            default = 15;
            description = "Tempo máximo de espera pelo endpoint.";
          };

          intervalSeconds = lib.mkOption {
            type = lib.types.addCheck lib.types.number (value: value > 0);
            default = 0.2;
            description = "Intervalo entre tentativas do health check.";
          };
        };
      };
    }
  );
}
