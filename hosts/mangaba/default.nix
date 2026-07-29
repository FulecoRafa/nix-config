{ config, lib, pkgs, inputs, root, ... }:

# mangaba — homelab.
#
# Orquestração é Nix puro: sem k3s, sem OCI containers. Todo serviço do plano
# acabou tendo módulo nativo no nixpkgs, então nada precisou virar container.
#
# Orçamento de RAM (8GB): ~4GB em uso, ~3GB livres para page cache — é o page
# cache que evita I/O em streaming. Por isso Karakeep e Gatus vêm desligados.
{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix
    ./storage.nix
    ./tailscale.nix
    ./dns.nix
    ./media.nix
    ./music.nix
    ./apps.nix
    ./sync.nix
    ./monitoring.nix
    ./backup.nix
    (root + /termapps/system.bundle.nix)
  ];

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    # O store cresce sozinho com rebuild de servidor; sem isso o disco enche.
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    optimise.automatic = true;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # RAM é o gargalo, não CPU: comprimir páginas frias vale muito mais que
  # ir para o swap em disco.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  networking.hostName = "mangaba";

  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "en_US.UTF-8";

  # TODO: trocar pelo nome MagicDNS real depois do primeiro `tailscale up`
  # (`tailscale status --json | jq -r .Self.DNSName`).
  mangaba.tailscale.fqdn = "mangaba.tailnet.ts.net";

  # Segredos: ligar depois de gerar secrets/mangaba.yaml (ver secrets.nix).
  # Enquanto isso, restic e slskd ficam fora, e o Tailscale entra com
  # `tailscale up` manual.
  mangaba.secrets = {
    enable = false;
    file = root + /secrets/mangaba.yaml;
  };

  # Ferramentas que aparecem no índice do Glance. O que não tem UI precisa
  # estar listado em algum lugar, senão só existe na memória de quem instalou.
  mangaba.cli = {
    nixos-rebuild = {
      command = "nixos-rebuild switch --flake .#mangaba";
      description = "Aplica mudanças da config; `--rollback` volta a geração anterior.";
      category = "Sistema";
    };
    systemctl = {
      description = "Estado dos serviços: `systemctl status jellyfin`, `systemctl list-timers`.";
      category = "Sistema";
    };
    journalctl = {
      description = "Logs: `journalctl -u mangaba-sync -n 50`, `-f` para acompanhar.";
      category = "Sistema";
    };
    tailscale = {
      description = "`tailscale status`, `tailscale serve status` para ver o que está publicado.";
      category = "Sistema";
    };
    btrfs = {
      description = "`btrfs filesystem usage /data` — espaço real, que o `df` erra em btrfs.";
      category = "Sistema";
    };
  };

  programs.fish.enable = true;
  users.users.fuleco = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      config.mangaba.storage.group
    ];
    initialPassword = "correcthorsebatterystaple";
    shell = pkgs.fish;
  };

  # Servidor headless: nada de suspender no meio de um download.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandlePowerKey = "poweroff";
  };
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
  };

  system.stateVersion = "25.05";
}
