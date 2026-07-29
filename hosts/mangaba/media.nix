{ config, lib, pkgs, ... }:

# Mídia — vídeo: Jellyfin + Prowlarr + Radarr/Sonarr + Bazarr + qBittorrent.
#
# Restrições de hardware (i7 3ª gen, Ivy Bridge):
#   - Quick Sync de 3ª gen só acelera H.264, MPEG-2 e VC-1. Nada de HEVC/VP9/AV1.
#   - O driver VAAPI correto para essa geração é o i965 (intel-vaapi-driver);
#     o intel-media-driver só cobre Broadwell+.
#   - Direct play é a prioridade: transcode é o que derruba essa máquina.
#
# BIOS: habilitar "iGPU Multi-Monitor" (ou equivalente), senão o
# /dev/dri/renderD128 não aparece sem monitor conectado e não há VAAPI.
let
  storage = config.mangaba.storage;
  data = storage.dataDir;
  group = storage.group;

  ports = {
    jellyfin = 8096;
    prowlarr = 9696;
    radarr = 7878;
    sonarr = 8989;
    bazarr = 6767;
    qbittorrent = 8080;
    torrenting = 51413;
  };
in
{
  # --- Aceleração de vídeo -------------------------------------------------
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver # i965 — Ivy Bridge
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  # --- Jellyfin ------------------------------------------------------------
  services.jellyfin = {
    enable = true;
    inherit group;
    openFirewall = false; # acesso só pelo tailnet

    hardwareAcceleration = {
      enable = true;
      type = "vaapi";
      device = "/dev/dri/renderD128";
    };

    # A config do Nix passa a ser a fonte da verdade do encoding.xml.
    forceEncodingConfig = true;

    transcoding = {
      # 8GB de RAM e Ivy Bridge: mais de um transcode simultâneo derruba tudo.
      maxConcurrentStreams = 2;
      # Tone mapping de HDR é feito em software aqui — caro demais.
      enableToneMapping = false;
      throttleTranscoding = true;
      hardwareDecodingCodecs = {
        h264 = true;
        mpeg2 = true;
        vc1 = true;
      };
      # Sem encoder de HEVC/AV1 nessa geração. H.264 já é sempre habilitado.
      hardwareEncodingCodecs = { };
    };
  };

  users.users.jellyfin.extraGroups = [
    "render"
    "video"
  ];

  # --- Indexadores e automação --------------------------------------------
  # Prowlarr roda com DynamicUser e não toca /data, então fica fora do grupo.
  services.prowlarr = {
    enable = true;
    settings.server = {
      port = ports.prowlarr;
      bindaddress = "127.0.0.1";
    };
  };

  services.radarr = {
    enable = true;
    inherit group;
    settings.server = {
      port = ports.radarr;
      bindaddress = "127.0.0.1";
    };
  };

  services.sonarr = {
    enable = true;
    inherit group;
    settings.server = {
      port = ports.sonarr;
      bindaddress = "127.0.0.1";
    };
  };

  services.bazarr = {
    enable = true;
    inherit group;
    listenPort = ports.bazarr;
  };

  # --- Cliente de download -------------------------------------------------
  services.qbittorrent = {
    enable = true;
    user = "qbittorrent";
    inherit group;
    webuiPort = ports.qbittorrent;
    torrentingPort = ports.torrenting;
    # Só a porta de torrent precisa vir da internet; a WebUI sai pelo tailnet.
    openFirewall = false;

    serverConfig = {
      LegalNotice.Accepted = true;
      Preferences = {
        General.Locale = "en";
        WebUI = {
          Address = "127.0.0.1";
          LocalHostAuth = false;
        };
        Downloads = {
          SavePath = "${data}/torrents";
          TempPathEnabled = false;
        };
        # Hardlink depende do arquivo continuar no lugar depois do import.
        Bittorrent.MaxRatio = -1;
      };
      BitTorrent.Session = {
        DefaultSavePath = "${data}/torrents";
        Port = ports.torrenting;
        # Pré-alocar mata o benefício do +C em btrfs e enche o disco antes da
        # hora; com CoW desligado a fragmentação já está controlada.
        Preallocation = false;
        # Categorias alinhadas ao layout de /data — os *arr importam daqui.
        TorrentExportDirectory = "${data}/torrents";
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ ports.torrenting ];
    allowedUDPPorts = [ ports.torrenting ];
  };

  systemd.services = lib.mkMerge [
    # umask 002 para todo mundo que escreve em /data: o módulo do sonarr/radarr
    # fixa 0022, o que quebraria a escrita cruzada dentro do grupo `media`.
    (lib.genAttrs
      [
        "sonarr"
        "radarr"
        "bazarr"
        "qbittorrent"
        "jellyfin"
      ]
      (_: {
        serviceConfig.UMask = lib.mkForce "0002";
      })
    )
    { jellyfin.environment.LIBVA_DRIVER_NAME = "i965"; }
  ];

  # --- Publicação no tailnet ----------------------------------------------
  mangaba.tailscale.serve = {
    jellyfin = {
      port = ports.jellyfin;
      target = "http://127.0.0.1:${toString ports.jellyfin}";
      title = "Jellyfin";
      description = "Filmes, séries e streaming.";
      category = "Mídia";
      icon = "di:jellyfin";
    };
    prowlarr = {
      port = ports.prowlarr;
      target = "http://127.0.0.1:${toString ports.prowlarr}";
      title = "Prowlarr";
      description = "Indexadores compartilhados com Radarr/Sonarr.";
      category = "Mídia";
      icon = "di:prowlarr";
    };
    radarr = {
      port = ports.radarr;
      target = "http://127.0.0.1:${toString ports.radarr}";
      title = "Radarr";
      description = "Aquisição e organização de filmes.";
      category = "Mídia";
      icon = "di:radarr";
    };
    sonarr = {
      port = ports.sonarr;
      target = "http://127.0.0.1:${toString ports.sonarr}";
      title = "Sonarr";
      description = "Aquisição e organização de séries.";
      category = "Mídia";
      icon = "di:sonarr";
    };
    bazarr = {
      port = ports.bazarr;
      target = "http://127.0.0.1:${toString ports.bazarr}";
      title = "Bazarr";
      description = "Legendas para o que o Radarr/Sonarr baixa.";
      category = "Mídia";
      icon = "di:bazarr";
    };
    qbittorrent = {
      port = ports.qbittorrent;
      target = "http://127.0.0.1:${toString ports.qbittorrent}";
      title = "qBittorrent";
      description = "Cliente de torrent; downloads em ${data}/torrents.";
      category = "Mídia";
      icon = "di:qbittorrent";
    };
  };

  # NOTA — o que não dá para declarar aqui:
  #   Radarr/Sonarr/Bazarr guardam config em SQLite próprio. Depois do primeiro
  #   boot, aplicar na UI:
  #     - Root folder: ${data}/media/movies e ${data}/media/tv
  #     - Download client: qBittorrent em 127.0.0.1:${toString ports.qbittorrent}
  #     - Remote path mapping: nenhum (mesmo filesystem, hardlink direto)
  #     - Naming scheme do TRaSH Guides — é o que faz o Jellyfin acertar
  #       metadados e capa sozinho
  #     - Bazarr: OpenSubtitles.com + Podnapisi, score mínimo alto, upgrade on
}
