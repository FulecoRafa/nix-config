{ config, lib, pkgs, ... }:

# Sincronização entre máquinas com rsync, num timer de 15 em 15 minutos.
#
# Isto é replicação, não backup: um `rm` do lado de origem propaga na próxima
# passada. O que protege contra isso é o restic (ver backup.nix).
#
# O transporte é o SSH do Tailscale — sem porta aberta, sem chave para
# gerenciar, a ACL do tailnet é a autorização.
let
  cfg = config.mangaba.sync;

  # Os jobs são declarados no Nix e renderizados para JSON. O daemon lê esse
  # arquivo em runtime, então dá para inspecionar exatamente o que ele vai
  # fazer sem ler o Nix:  jq . /etc/mangaba/sync.json
  configFile = (pkgs.formats.json { }).generate "mangaba-sync.json" {
    jobs = lib.mapAttrsToList (name: job: {
      inherit name;
      inherit (job)
        source
        destination
        delete
        extraArgs
        ;
    }) (lib.filterAttrs (_: job: job.enable) cfg.jobs);
  };

  runner = pkgs.writeShellApplication {
    name = "mangaba-sync";
    runtimeInputs = with pkgs; [
      rsync
      jq
      openssh
    ];
    text = ''
      config=''${1:-${cfg.configFile}}
      failed=0

      count=$(jq '.jobs | length' "$config")
      if [ "$count" -eq 0 ]; then
        echo "nenhum job de sync configurado"
        exit 0
      fi

      for i in $(seq 0 $((count - 1))); do
        name=$(jq -r ".jobs[$i].name" "$config")
        source=$(jq -r ".jobs[$i].source" "$config")
        destination=$(jq -r ".jobs[$i].destination" "$config")
        delete=$(jq -r ".jobs[$i].delete" "$config")
        mapfile -t extra < <(jq -r ".jobs[$i].extraArgs[]" "$config")

        args=(--archive --partial --human-readable --stats)
        if [ "$delete" = "true" ]; then
          args+=(--delete)
        fi
        if [ ''${#extra[@]} -gt 0 ]; then
          args+=("''${extra[@]}")
        fi

        echo "==> $name: $source -> $destination"
        # Um job que falha (máquina de origem offline, por exemplo) não pode
        # impedir os outros de rodar; o status geral vai no fim.
        if ! rsync "''${args[@]}" "$source" "$destination"; then
          echo "!!! $name falhou" >&2
          failed=$((failed + 1))
        fi
      done

      exit "$failed"
    '';
  };
in
{
  options.mangaba.sync = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Timer de sincronização via rsync.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "15m";
      description = "Intervalo entre passadas (formato de tempo do systemd).";
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/mangaba/sync.json";
      description = ''
        Onde os jobs renderizados ficam no disco. O runner aceita um caminho
        alternativo como primeiro argumento — útil para testar um conjunto de
        jobs sem rebuild: `mangaba-sync /tmp/jobs.json`.
      '';
    };

    jobs = lib.mkOption {
      default = { };
      description = ''
        Jobs de rsync. Origem e destino são caminhos rsync: local, ou
        `host:/caminho` usando o nome MagicDNS da outra máquina.

        Barra no fim da origem importa: `dir/` copia o conteúdo, `dir` copia o
        diretório.
      '';
      example = lib.literalExpression ''
        {
          documentos = {
            source = "tamarindo:/home/fuleco/documentos/";
            destination = "/data/sync/documentos";
            delete = true;
          };
        }
      '';
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Desligar um job sem apagar a declaração.";
            };

            source = lib.mkOption {
              type = lib.types.str;
              description = "Origem, no formato do rsync.";
            };

            destination = lib.mkOption {
              type = lib.types.str;
              description = "Destino, no formato do rsync.";
            };

            delete = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Apagar no destino o que não existe mais na origem. É o que faz
                a réplica ser fiel — e o que faz um `rm` acidental se propagar.
              '';
            };

            extraArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              example = [
                "--exclude=.git"
                "--bwlimit=10M"
              ];
              description = "Argumentos extras passados ao rsync.";
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      runner
      pkgs.rsync
    ];

    environment.etc."mangaba/sync.json".source = configFile;

    mangaba.cli.mangaba-sync = {
      description = "Roda os jobs de rsync agora (${cfg.interval} no timer); aceita outro JSON como argumento.";
      category = "Infra";
    };

    systemd.services.mangaba-sync = {
      description = "Sincronização rsync";
      after = [
        "network-online.target"
        "tailscaled.service"
      ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe runner} ${cfg.configFile}";
        # Escreve em /data, que é do grupo `media`.
        UMask = "0002";
        SupplementaryGroups = [ config.mangaba.storage.group ];
        # Sync não pode competir com o streaming do Jellyfin.
        Nice = 10;
        IOSchedulingClass = "idle";
      };

      restartTriggers = [ configFile ];
    };

    systemd.timers.mangaba-sync = {
      description = "Sincronização rsync a cada ${cfg.interval}";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = cfg.interval;
        # Se a máquina estava desligada na hora, roda assim que voltar.
        Persistent = true;
        AccuracySec = "1m";
      };
    };
  };
}
