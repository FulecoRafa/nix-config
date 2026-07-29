{ config, lib, pkgs, ... }:

# Mídia — música: Navidrome (servidor Subsonic) + beets (tagging/organização)
# + slskd (aquisição).
#
# Lidarr ficou de fora de propósito: matching fraco. O beets faz o trabalho de
# metadados muito melhor, e o slskd cobre a aquisição.
let
  storage = config.mangaba.storage;
  data = storage.dataDir;
  group = storage.group;

  ports = {
    navidrome = 4533;
    slskd = 5030;
    soulseek = 50300;
  };

  musicLibrary = "${data}/media/music";
  beetsDir = "/var/lib/beets";

  # Config do beets declarada no Nix. Todos os plugins usados aqui são builtin
  # do pacote `beets` do nixpkgs, que já vem com as dependências.
  beetsConfig = (pkgs.formats.yaml { }).generate "beets-config.yaml" {
    directory = musicLibrary;
    library = "${beetsDir}/library.db";

    # Mover, não copiar: a origem é o diretório de download.
    import = {
      move = true;
      write = true;
      copy = false;
      resume = true;
      incremental = true;
      log = "${beetsDir}/import.log";
    };

    plugins = [
      "fetchart"
      "embedart"
      "chroma"
      "lyrics"
      "replaygain"
      "scrub"
    ];

    paths = {
      default = "$albumartist/$album%aunique{}/$track $title";
      singleton = "Non-Album/$artist/$title";
      comp = "Compilations/$album%aunique{}/$track $title";
    };

    fetchart = {
      auto = true;
      cautious = true;
      sources = [
        "filesystem"
        "coverart"
        "itunes"
        "albumart"
      ];
    };

    embedart.auto = true;

    # scrub roda antes do write, senão apaga as tags recém escritas.
    scrub.auto = true;

    replaygain = {
      auto = true;
      backend = "ffmpeg";
    };
  };

  beets = pkgs.symlinkJoin {
    name = "beets-mangaba";
    paths = [ pkgs.beets ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/beet --add-flags "--config ${beetsConfig}"
    '';
  };
in
{
  # --- Navidrome -----------------------------------------------------------
  services.navidrome = {
    enable = true;
    inherit group;
    openFirewall = false;

    settings = {
      Address = "127.0.0.1";
      Port = ports.navidrome;
      MusicFolder = musicLibrary;
      # O scan periódico custa I/O; o beets é quem move os arquivos, então um
      # scan de hora em hora é suficiente.
      ScanSchedule = "@every 1h";
      EnableInsightsCollector = false;
    };
  };

  # --- beets ---------------------------------------------------------------
  environment.systemPackages = [ beets ];

  mangaba.cli.beet = {
    description = "Importa, marca e organiza a biblioteca (`beet import <dir>`).";
    category = "Música";
  };

  systemd.tmpfiles.rules = [
    "d ${beetsDir} 2775 root ${group} - -"
  ];

  # --- slskd ---------------------------------------------------------------
  # O módulo exige `environmentFile` (usuário e senha do Soulseek não podem ir
  # para o nix store), então o slskd só sobe com os segredos configurados.
  services.slskd = lib.mkIf config.mangaba.secrets.enable {
    enable = true;
    inherit group;
    openFirewall = false;
    domain = null; # sem vhost nginx — o acesso é via tailscale serve

    # SLSKD_SLSK_USERNAME / SLSKD_SLSK_PASSWORD / SLSKD_USERNAME / SLSKD_PASSWORD
    environmentFile = config.mangaba.secrets.path "slskd/env";

    settings = {
      directories = {
        downloads = "${data}/torrents/music";
        incomplete = "${data}/torrents/music/.incomplete";
      };
      shares.directories = [ musicLibrary ];
      soulseek.listen_port = ports.soulseek;
      web = {
        port = ports.slskd;
      };
    };
  };

  mangaba.secrets.declare = lib.mkIf config.mangaba.secrets.enable {
    "slskd/env" = {
      restartUnits = [ "slskd.service" ];
    };
  };

  systemd.services.slskd = lib.mkIf config.mangaba.secrets.enable {
    serviceConfig.UMask = lib.mkForce "0002";
  };

  networking.firewall.allowedTCPPorts = lib.optional config.mangaba.secrets.enable ports.soulseek;

  # --- Publicação no tailnet ----------------------------------------------
  mangaba.tailscale.serve = {
    navidrome = {
      port = ports.navidrome;
      target = "http://127.0.0.1:${toString ports.navidrome}";
      title = "Navidrome";
      description = "Servidor Subsonic da biblioteca de música.";
      category = "Música";
      icon = "di:navidrome";
    };
  }
  // lib.optionalAttrs config.mangaba.secrets.enable {
    slskd = {
      port = ports.slskd;
      target = "http://127.0.0.1:${toString ports.slskd}";
      title = "slskd";
      description = "Soulseek — aquisição de música.";
      category = "Música";
      icon = "di:slskd";
    };
  };
}
