{ config, lib, pkgs, ... }:

# Rede e acesso: Tailscale + `tailscale serve`.
#
# Cada serviço ganha uma porta HTTPS no tailnet com certificado válido, sem
# ingress, sem cert-manager, sem DNS challenge:
#   https://<host>.<tailnet>.ts.net:8096  ->  http://127.0.0.1:8096
#
# SSH é o Tailscale SSH — a ACL do tailnet é a autorização, não authorized_keys.
let
  cfg = config.mangaba.tailscale;

  # 443 é o endereço "sem porta" do host — quem entra por ele cai no índice.
  mkUrl = port: if port == 443 then "https://${cfg.fqdn}" else "https://${cfg.fqdn}:${toString port}";

  serveCmds = lib.mapAttrsToList (
    _: s: "${lib.getExe pkgs.tailscale} serve --bg --https=${toString s.port} ${s.target}"
  ) cfg.serve;
in
{
  options.mangaba.tailscale = {
    fqdn = lib.mkOption {
      type = lib.types.str;
      example = "mangaba.tail1234.ts.net";
      description = ''
        Nome MagicDNS completo do host. Usado para montar as URLs públicas dos
        serviços (ROOT_URL do Forgejo, base-url do ntfy, domain do Vaultwarden).
      '';
    };

    serve = lib.mkOption {
      default = { };
      description = ''
        Serviços expostos no tailnet via `tailscale serve`. Cada entrada também
        vira um link no índice do Glance (ver monitoring.nix), por isso os
        campos de apresentação moram aqui: quem declara o serviço é quem sabe
        como ele se chama e a que grupo pertence.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              port = lib.mkOption {
                type = lib.types.port;
                description = "Porta HTTPS no tailnet.";
              };
              target = lib.mkOption {
                type = lib.types.str;
                example = "http://127.0.0.1:8096";
                description = "Upstream local.";
              };
              title = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Nome exibido no índice.";
              };
              description = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "Uma linha sobre o que o serviço faz.";
              };
              category = lib.mkOption {
                type = lib.types.str;
                default = "Serviços";
                description = "Grupo no índice (Mídia, Apps, Infra...).";
              };
              icon = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                example = "di:jellyfin";
                description = "Ícone no formato do Glance (`di:`, `si:`, `sh:` ou URL).";
              };
              index = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Listar no índice. Desligar para o próprio dashboard.";
              };
            };
          }
        )
      );
    };

    urls = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = lib.mapAttrs (_: s: mkUrl s.port) cfg.serve;
      description = "URL pública de cada serviço servido. Derivado de `serve`.";
    };
  };

  config = {
    services.tailscale = {
      enable = true;
      # Necessário para subnet router e exit node.
      useRoutingFeatures = "both";
      openFirewall = true;
      authKeyFile = lib.mkIf config.mangaba.secrets.enable (
        config.mangaba.secrets.path "tailscale/authkey"
      );
      extraUpFlags = [
        "--ssh"
        "--advertise-exit-node"
        # O DNS da rede é o AdGuard que roda aqui mesmo; não deixar o tailscaled
        # sobrescrever o resolv.conf local.
        "--accept-dns=false"
      ];
    };

    mangaba.secrets.declare = lib.mkIf config.mangaba.secrets.enable {
      "tailscale/authkey" = {
        restartUnits = [ "tailscaled-autoconnect.service" ];
      };
    };

    # Toda a autorização de acesso vem do tailnet.
    services.openssh.enable = true;
    services.openssh.openFirewall = false;

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      # Necessário para o exit node funcionar com o path filter do kernel.
      checkReversePath = "loose";
    };

    systemd.services.tailscale-mangaba-serve = lib.mkIf (cfg.serve != { }) {
      description = "Publica os serviços do homelab via tailscale serve";
      after = [
        "tailscaled.service"
        "tailscaled-autoconnect.service"
      ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      # `reset` antes de aplicar: o estado do serve vive no tailscaled, então
      # sem isso um serviço removido daqui continuaria publicado.
      script = lib.concatStringsSep "\n" (
        [ "${lib.getExe pkgs.tailscale} serve reset" ] ++ serveCmds
      );
    };
  };
}
