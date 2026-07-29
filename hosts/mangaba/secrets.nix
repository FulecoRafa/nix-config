{ config, lib, inputs, ... }:

# Estratégia de segredos: sops-nix com a chave de host SSH como chave age.
#
# Enquanto `mangaba.secrets.enable` for false, nenhum arquivo criptografado é
# exigido — a config avalia e builda normalmente, e os módulos que dependem de
# segredo (restic, authkey do Tailscale, environmentFile do Glance) ficam
# desligados ou apontam para o diretório de fallback.
#
# Para ligar:
#   1. nix-shell -p ssh-to-age --run \
#        'ssh-keyscan mangaba | ssh-to-age'          # chave age do host
#   2. escrever secrets/mangaba.yaml com `sops` usando essa chave em .sops.yaml
#   3. mangaba.secrets = { enable = true; file = ../../secrets/mangaba.yaml; };
let
  cfg = config.mangaba.secrets;
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.mangaba.secrets = {
    enable = lib.mkEnableOption "segredos gerenciados por sops-nix";

    file = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Arquivo sops YAML com todos os segredos do host.";
    };

    declare = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = ''
        Segredos que os módulos do homelab precisam. Chave é o caminho dentro
        do arquivo sops, valor é a config de `sops.secrets.<nome>`
        (owner, mode, restartUnits...).
      '';
    };

    path = lib.mkOption {
      type = lib.types.functionTo lib.types.str;
      readOnly = true;
      default =
        name:
        if cfg.enable then
          config.sops.secrets.${name}.path
        else
          "/run/mangaba-secrets/${lib.replaceStrings [ "/" ] [ "-" ] name}";
      description = ''
        Resolve o caminho em runtime de um segredo declarado. Com sops
        desligado devolve um caminho em /run que não existe — serve só para a
        config avaliar.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.file != null;
        message = "mangaba.secrets.enable exige mangaba.secrets.file";
      }
    ];

    sops = {
      defaultSopsFile = cfg.file;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets = cfg.declare;
    };
  };
}
