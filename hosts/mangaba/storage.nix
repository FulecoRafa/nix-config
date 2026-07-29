{ config, lib, ... }:

# Layout de disco do plano: downloads e biblioteca no MESMO filesystem, sob uma
# raiz única, senão Radarr/Sonarr copiam em vez de fazer hardlink.
#
#   /data/
#     torrents/{movies,tv,music}
#     media/{movies,tv,music}
#
# Nada de bind mount por serviço. Todo serviço que toca /data entra no grupo
# `media` e roda com umask 002.
let
  cfg = config.mangaba.storage;

  # 2775 = setgid, para arquivo novo herdar o grupo `media`.
  dir = path: "d ${path} 2775 root ${cfg.group} - -";
in
{
  options.mangaba.storage = {
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/data";
      description = "Raiz única de downloads + biblioteca. Um único mount.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Grupo compartilhado por Jellyfin, *arr e cliente de download.";
    };

    disableCoW = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Em btrfs, marca o diretório de downloads com +C. Escrita aleatória de
        torrent fragmenta demais com CoW ligado. Só vale para diretório vazio —
        arquivos já gravados mantêm o atributo antigo.
      '';
    };
  };

  config = {
    users.groups.${cfg.group} = { };

    systemd.tmpfiles.rules = [
      (dir cfg.dataDir)
      (dir "${cfg.dataDir}/torrents")
      (dir "${cfg.dataDir}/torrents/movies")
      (dir "${cfg.dataDir}/torrents/tv")
      (dir "${cfg.dataDir}/torrents/music")
      (dir "${cfg.dataDir}/media")
      (dir "${cfg.dataDir}/media/movies")
      (dir "${cfg.dataDir}/media/tv")
      (dir "${cfg.dataDir}/media/music")
    ]
    ++ lib.optional cfg.disableCoW "h ${cfg.dataDir}/torrents - - - - +C";
  };
}
