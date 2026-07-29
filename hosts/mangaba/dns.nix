{ config, lib, ... }:

# DNS + ad-block da rede. Fica no LAN (porta 53 na rede local) e a UI sai pelo
# tailnet como todo o resto.
let
  webPort = 3003; # 3000 é do Forgejo
in
{
  services.adguardhome = {
    enable = true;
    host = "127.0.0.1";
    port = webPort;
    openFirewall = false; # a porta 53 é aberta manualmente abaixo
    # O bloqueio de listas e clientes é operação do dia a dia, não config de
    # sistema — deixar editável pela UI e só semear o estado inicial.
    mutableSettings = true;

    settings = {
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [
          "https://dns.quad9.net/dns-query"
          "https://dns.cloudflare.com/dns-query"
        ];
        bootstrap_dns = [
          "9.9.9.9"
          "1.1.1.1"
        ];
        # Só responde para a rede local e para o tailnet.
        ratelimit = 30;
      };
      filtering = {
        protection_enabled = true;
        filtering_enabled = true;
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };

  mangaba.tailscale.serve.adguard = {
    port = webPort;
    target = "http://127.0.0.1:${toString webPort}";
    title = "AdGuard Home";
    description = "DNS e bloqueio de anúncios da rede.";
    category = "Infra";
    icon = "di:adguard-home";
  };
}
