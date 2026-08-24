{ config, lib, ... }:
let
  cfg = config.dockerHost;
in
{
  options.dockerHost = {
    enable = lib.mkEnableOption "Docker com limpeza automática";
    user = lib.mkOption {
      type = lib.types.str;
      default = "fuleco";
      description = "Usuário incluído no grupo docker.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };
    users.users.${cfg.user}.extraGroups = [ "docker" ];
  };
}
