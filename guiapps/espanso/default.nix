{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:

# O arquivo de matches precisa continuar gravável: ele é compartilhado entre
# as máquinas pelo mangaba, portanto não pode ser um symlink para o Nix store.
let
  localFile = "${config.xdg.configHome}/espanso/match/base.yml";
  remoteHost = "fuleco@mangaba";
  remoteFile = "/data/sync/espanso/base.yml";

  # Wrapper com capabilities criado por ./system.nix (NixOS com Wayland).
  wrapperDir = osConfig.security.wrapperDir or "/run/wrappers/bin";
  hasWrapper = (osConfig.security.wrappers or { }) ? espanso;

  emptyMatches = pkgs.writeText "espanso-base.yml" ''
    # Adicione seus atalhos aqui. Exemplo:
    # matches:
    #   - trigger: ":email"
    #     replace: "voce@example.com"
    matches: []
  '';

  sync = pkgs.writeShellApplication {
    name = "espanso-sync";
    runtimeInputs = with pkgs; [
      coreutils
      openssh
      rsync
    ];
    text = ''
      local_file=${lib.escapeShellArg localFile}
      remote_host=${lib.escapeShellArg remoteHost}
      remote_file=${lib.escapeShellArg remoteFile}
      remote="$remote_host:$remote_file"
      ssh_command="ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
      rsync_args=(--archive --update --human-readable --itemize-changes)

      mkdir -p "$(dirname "$local_file")"

      # Se já houver uma cópia central, traz primeiro a versão mais nova. Em
      # seguida publica a local caso ela tenha sido editada mais recentemente.
      # O relógio das máquinas precisa estar sincronizado para o --update.
      if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
        "$remote_host" test -f "$remote_file"; then
        rsync "''${rsync_args[@]}" -e "$ssh_command" "$remote" "$local_file"
      fi

      rsync "''${rsync_args[@]}" -e "$ssh_command" "$local_file" "$remote"
    '';
  };
in
{
  services.espanso = {
    enable = true;

    # Só o default.yml vem do Home Manager; os matches (base.yml) precisam
    # ser editáveis e sincronizados em runtime, fora do Nix store.
    # No Hyprland o Alt+Espaço da busca do espanso disparava junto com o
    # Super+Alt+Espaço (troca de layout do teclado): fica Alt+Shift+Espaço.
    configs = lib.optionalAttrs pkgs.stdenv.isLinux {
      default.search_shortcut = "ALT+SHIFT+SPACE";
    };
    matches = { };

    package-wayland = lib.mkIf hasWrapper (
      pkgs.writeShellScriptBin "espanso" ''
        exec ${wrapperDir}/espanso "$@"
      ''
    );
  };

  home.packages = [ sync ];

  home.activation.ensureEspansoMatches = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg (builtins.dirOf localFile)}
    if [ ! -e ${lib.escapeShellArg localFile} ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0644 ${emptyMatches} ${lib.escapeShellArg localFile}
      # Uma máquina nova nunca deve substituir uma configuração que já esteja
      # no mangaba só porque o placeholder acabou de ser criado.
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/touch -d @1 ${lib.escapeShellArg localFile}
    fi
  '';

  systemd.user.services.espanso-sync = {
    Unit = {
      Description = "Sincroniza os matches do Espanso com o mangaba";
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe sync;
    };
  };

  systemd.user.timers.espanso-sync = {
    Unit.Description = "Sincroniza os matches do Espanso a cada 15 minutos";
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "15m";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
