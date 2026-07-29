{ config, lib, pkgs, ... }:

# Backup: restic via `services.restic.backups` (timer systemd).
# Snapshot versionado, dedup, criptografia e retenção — rsync é replicação,
# não backup, e não substitui isto.
#
# O que entra: estado dos serviços (/var/lib) e a config. A biblioteca de mídia
# NÃO entra — é grande e recuperável; se quiser cobri-la, use um repo separado
# com outra política de retenção.
let
  cfg = config.mangaba.backup;
  secrets = config.mangaba.secrets;

  # Estado que dói perder. Cada um desses tem um serviço parado ou uma senha
  # atrás.
  paths = [
    "/var/lib/vaultwarden"
    "/var/lib/forgejo"
    "/var/lib/private/actual"
    "/var/lib/sonarr"
    "/var/lib/radarr"
    "/var/lib/private/prowlarr"
    "/var/lib/bazarr"
    "/var/lib/jellyfin"
    "/var/lib/navidrome"
    "/var/lib/beets"
    "/var/lib/qBittorrent"
    "/var/lib/AdGuardHome"
  ];

  exclude = [
    "**/cache"
    "**/Cache"
    "/var/lib/jellyfin/transcodes"
    "/var/lib/jellyfin/metadata"
  ];

  retention = [
    "--keep-daily 7"
    "--keep-weekly 5"
    "--keep-monthly 12"
  ];

  common = {
    inherit paths exclude;
    initialize = true;
    passwordFile = secrets.path "restic/password";
    pruneOpts = retention;
    # Hoje todo serviço daqui usa SQLite, e o snapshot do diretório basta. Se
    # algum passar a usar Postgres, ele não pode ser copiado a quente pelo
    # diretório — daí o dump.
    backupPrepareCommand = lib.optionalString config.services.postgresql.enable ''
      ${pkgs.coreutils}/bin/install -d -m 0700 ${cfg.dumpDir}
      ${pkgs.util-linux}/bin/runuser -u postgres -- \
        ${config.services.postgresql.package}/bin/pg_dumpall \
        | ${pkgs.gzip}/bin/gzip > ${cfg.dumpDir}/postgres.sql.gz
    '';
  };

  dumpPaths = lib.optional config.services.postgresql.enable cfg.dumpDir;
in
{
  options.mangaba.backup = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.mangaba.secrets.enable;
      description = ''
        Backups exigem a senha do repositório fora do nix store, então seguem o
        estado de `mangaba.secrets.enable`.
      '';
    };

    localRepository = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/backup/restic";
      description = "Repositório no HDD externo.";
    };

    remote.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Segundo repositório fora de casa (bucket). Exige os segredos
        `restic/remote-repository` e `restic/remote-env` (credenciais do S3).
      '';
    };

    dumpDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/backup/dumps";
      description = "Onde os dumps de banco são gerados antes de entrarem no snapshot.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.restic.backups = {
      local = common // {
        repository = cfg.localRepository;
        paths = paths ++ dumpPaths;
        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "1h";
          Persistent = true;
        };
      };
    }
    // lib.optionalAttrs cfg.remote.enable {
      remote = common // {
        repositoryFile = secrets.path "restic/remote-repository";
        environmentFile = secrets.path "restic/remote-env";
        paths = paths ++ dumpPaths;
        timerConfig = {
          OnCalendar = "weekly";
          RandomizedDelaySec = "3h";
          Persistent = true;
        };
      };
    };

    # O módulo do restic instala um wrapper por backup, já com repositório e
    # senha no ambiente — é por ele que se navega e restaura.
    mangaba.cli = {
      restic-local = {
        description = "Repositório local: `restic-local snapshots`, `restic-local restore <id> --target /tmp/x`.";
        category = "Infra";
      };
    }
    // lib.optionalAttrs cfg.remote.enable {
      restic-remote = {
        description = "Mesmo wrapper, apontando para o repositório fora de casa.";
        category = "Infra";
      };
    };

    systemd.tmpfiles.rules = lib.optional config.services.postgresql.enable (
      "d ${cfg.dumpDir} 0700 root root - -"
    );

    mangaba.secrets.declare = {
      "restic/password" = { };
    }
    // lib.optionalAttrs cfg.remote.enable {
      "restic/remote-repository" = { };
      "restic/remote-env" = { };
    };
  };
}
