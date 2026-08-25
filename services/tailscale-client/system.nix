{ ... }:

# Cliente persistente do tailnet. A autenticação inicial é deliberadamente
# interativa (`sudo tailscale up`), portanto nenhuma auth key entra no store.
{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "client";
  };

  # A ACL do tailnet controla quem alcança o host; a interface deixa de ser
  # filtrada uma segunda vez pelo firewall local.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
