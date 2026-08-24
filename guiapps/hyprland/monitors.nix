{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hyprlandDesktop.monitors;
  monitorctl = pkgs.writeShellApplication {
    name = "hyprland-monitorctl";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.hyprland
    ];
    text = builtins.readFile ./monitorctl;
  };
  renderMonitor =
    monitor:
    lib.concatStringsSep ", " (
      [
        monitor.name
        monitor.mode
        monitor.position
        monitor.scale
      ]
      ++ lib.optionals (monitor.transform != null) [
        "transform"
        (toString monitor.transform)
      ]
    );
in
{
  options.hyprlandDesktop.monitors = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            example = "DP-1";
            description = "Nome do conector informado por hyprctl monitors.";
          };
          mode = lib.mkOption {
            type = lib.types.str;
            default = "preferred";
            example = "2560x1440@144";
          };
          position = lib.mkOption {
            type = lib.types.str;
            default = "auto";
            example = "0x0";
          };
          scale = lib.mkOption {
            type = lib.types.str;
            default = "auto";
            example = "1.25";
          };
          transform = lib.mkOption {
            type = lib.types.nullOr (lib.types.ints.between 0 7);
            default = null;
            description = "Transformação do Hyprland (0 a 7), se necessária.";
          };
        };
      }
    );
    default = [ ];
    description = "Monitores declarativos do Hyprland; vazio usa descoberta automática.";
  };

  config = {
    home.packages = [ monitorctl ];

    home.activation.hyprlandMonitorRuntime = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      runtime_dir="$HOME/.config/hyprland"
      run mkdir -p "$runtime_dir"
      if [[ ! -e "$runtime_dir/monitors-runtime.conf" ]]; then
        run touch "$runtime_dir/monitors-runtime.conf"
      fi
    '';

    wayland.windowManager.hyprland = {
      settings.monitor = if cfg == [ ] then [ ", preferred, auto, auto" ] else map renderMonitor cfg;
      extraConfig = ''
        # Ajustes persistidos pelo gerenciador de monitores.
        source = ~/.config/hyprland/monitors-runtime.conf
      '';
    };
  };
}
