{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hyprlandDesktop;
  workspaceCount = cfg.workspaceCount;
  workspaceNumbers = lib.range 1 workspaceCount;
  workspaceBinds = lib.concatMap (
    workspace:
    let
      number = toString workspace;
    in
    [
      "SUPER, ${number}, workspace, ${number}"
      "SUPER SHIFT, ${number}, movetoworkspace, ${number}"
    ]
  ) workspaceNumbers;

  quickshellExe = lib.getExe pkgs.quickshell;
  quickshellCtl = "${quickshellExe} -c fuleco ipc call";
in
{
  imports = [
    ./monitors.nix
    ./screenshots.nix
  ];

  options.hyprlandDesktop = {
    workspaceCount = lib.mkOption {
      type = lib.types.ints.between 1 9;
      default = 6;
      description = "Quantidade de workspaces persistentes e exibidos na barra.";
    };
    browserCommand = lib.mkOption {
      type = lib.types.str;
      default = "helium";
      description = "Comando executado pelo atalho do navegador.";
    };
  };

  config = {
    home.sessionVariables.HYPRLAND_WORKSPACE_COUNT = toString workspaceCount;

    home.packages = with pkgs; [
      brightnessctl
      cliphist
      hyprpicker
      imv
      libnotify
      mpv
      quickshell
      wl-clipboard
    ];

    programs.hyprlock.enable = true;

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = false; # UWSM owns the graphical session.

      settings = {
        "$terminal" = lib.getExe pkgs.ghostty;
        "$browser" = cfg.browserCommand;

        input = {
          follow_mouse = 1;
          repeat_delay = 250;
          repeat_rate = 35;
        };

        general.layout = "dwindle";

        dwindle = {
          preserve_split = true;
          pseudotile = true;
        };

        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
        };

        workspace = map (workspace: "${toString workspace}, persistent:true") workspaceNumbers;

        exec-once = [
          "${quickshellExe} -c fuleco"
        ];

        bind = [
          "SUPER, RETURN, exec, $terminal"
          "SUPER SHIFT, RETURN, exec, $browser"
          "SUPER, SPACE, exec, ${quickshellCtl} launcher toggle"
          "SUPER CTRL, V, exec, ${quickshellCtl} launcher clipboard"
          "SUPER CTRL, M, exec, ${quickshellCtl} monitors toggle"
          "SUPER CTRL, L, exec, ${lib.getExe pkgs.hyprlock}"
          "SUPER, W, killactive"
          "SUPER, F, fullscreen"
          "SUPER, T, togglefloating"
          "SUPER, J, togglesplit"
          "SUPER, left, movefocus, l"
          "SUPER, right, movefocus, r"
          "SUPER, up, movefocus, u"
          "SUPER, down, movefocus, d"
          ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && ${quickshellCtl} osd show Audio"
          ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && ${quickshellCtl} osd show Volume+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && ${quickshellCtl} osd show Volume-"
          ", XF86MonBrightnessUp, exec, brightnessctl set 5%+ && ${quickshellCtl} osd show Brightness+"
          ", XF86MonBrightnessDown, exec, brightnessctl set 5%- && ${quickshellCtl} osd show Brightness-"
        ]
        ++ workspaceBinds;

        bindm = [
          "SUPER, mouse:272, movewindow"
          "SUPER, mouse:273, resizewindow"
        ];
      };
    };

    xdg.configFile."quickshell/fuleco" = {
      source = ./quickshell;
      recursive = true;
    };

    xdg.desktopEntries.hyprland-monitors = {
      name = "Monitores";
      comment = "Posição, resolução e frequência dos monitores";
      exec = "${quickshellCtl} monitors toggle";
      icon = "video-display";
      categories = [ "Settings" ];
      terminal = false;
    };

    systemd.user.services = {
      cliphist-text = {
        Unit = {
          Description = "Store text clipboard history";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${lib.getExe pkgs.cliphist} store";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      cliphist-image = {
        Unit = {
          Description = "Store image clipboard history";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${lib.getExe pkgs.cliphist} store";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
