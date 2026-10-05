{
  config,
  fulecoLib,
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
  # Mostra o HUD do atalho (Hud.qml) junto com a ação.
  hud = id: "${quickshellCtl} hud flash ${id} & ";
  wallpaper = pkgs.callPackage ./wallpaper/package.nix { };
  phosphorIcons = pkgs.callPackage ./phosphor/package.nix { };
  # Dois dedos da borda direita do touchpad abrem/fecham a gaveta.
  edgeSwipe = pkgs.writers.writePython3Bin "edge-swipe" {
    libraries = [ pkgs.python3Packages.evdev ];
    flakeIgnore = [ "E501" "W503" ];
  } (builtins.readFile ./edge-swipe);
  # US ⇄ US internacional. O "next" vira cada teclado por conta própria e eles
  # se desencontram (o virtual do espanso inclusive); daqui todos vão para o
  # índice oposto ao do teclado principal.
  kbToggle = pkgs.writeShellScript "kb-layout-toggle" ''
    index=$(hyprctl devices -j | ${lib.getExe pkgs.jq} '[.keyboards[] | select(.main)][0].active_layout_index // 0')
    exec hyprctl switchxkblayout all $((1 - index))
  '';
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
      bluetui
      brightnessctl
      calcure
      cliphist
      hyprpicker
      imv
      libnotify
      mpv
      # Ícones do shell (Phosphor fill), usados pelo Quickshell.
      phosphorIcons
      playerctl
      (fulecoLib.mkLiveConfigPackage {
        package = quickshell;
        name = "quickshell";
        source = ./quickshell;
        target = ".config/quickshell/fuleco";
        repositoryPath = "guiapps/hyprland/quickshell";
      })
      # Clima animado no terminal; o widget da gaveta abre ele.
      weathr
      wifitui
      wiremix
      wl-clipboard
    ];

    services.liveConfig.entries.hyprland = {
      source = ./live;
      target = ".config/hypr/live";
      repositoryPath = "guiapps/hyprland/live";
    };

    home.file.".local/share/backgrounds/fuleco.png".source = wallpaper;

    # btop no tema Ayu e com o fundo transparente do Ghostty.
    programs.btop = {
      enable = true;
      settings = {
        color_theme = "ayu";
        theme_background = false;
        rounded_corners = true;
      };
    };

    # Bloqueia após 10 min parado e apaga a tela aos 12. A "cafeína" do shell
    # segura isso com um idle inhibitor enquanto estiver ligada.
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };
        listener = [
          {
            timeout = 600;
            on-timeout = "loginctl lock-session";
          }
          {
            timeout = 720;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
        ];
      };
    };

    programs.hyprlock = {
      enable = true;
      settings = {
        # Digital em paralelo com a senha, via fprintd (sem efeito sem leitor).
        auth = {
          "fingerprint:enabled" = true;
          "fingerprint:ready_message" = "toque o leitor ou digite a senha";
          "fingerprint:present_message" = "lendo digital…";
        };
        # Enter sem nada digitado não gasta uma tentativa no PAM.
        general.ignore_empty_input = true;
        background = [
          {
            path = "${wallpaper}";
            blur_passes = 2;
          }
        ];
        input-field = [
          {
            size = "320, 52";
            position = "0, -120";
            outer_color = "rgb(ff7a29)";
            inner_color = "rgb(10163a)";
            font_color = "rgb(f4ecd6)";
            placeholder_text = "$FPRINTPROMPT";
            fail_text = "$PAMFAIL";
            check_color = "rgb(ffc94a)";
            fail_color = "rgb(ff5a5f)";
            capslock_color = "rgb(ffc94a)";
          }
        ];
      };
    };

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = false; # UWSM owns the graphical session.

      # Por último, para sobrescrever o declarativo; editável via live-config.
      extraConfig = ''
        source = ${config.home.homeDirectory}/.config/hypr/live/user.conf
      '';

      settings = {
        "$terminal" = lib.getExe pkgs.ghostty;
        "$browser" = cfg.browserCommand;

        input = {
          follow_mouse = 1;
          repeat_delay = 250;
          repeat_rate = 35;
          # US para código e US internacional (teclas mortas) para acentos;
          # Super+Alt+Espaço alterna.
          kb_layout = "us,us";
          kb_variant = ",intl";
          # Caps Lock vira Esc e vice-versa.
          kb_options = "caps:swapescape";
          # Rolagem com dois dedos no mesmo sentido do macOS.
          touchpad.natural_scroll = true;
        };

        # Trocar de janela (atalho, barra, Alt+Tab) não teleporta o cursor.
        cursor.no_warps = true;

        # Bordas finas e discretas, como as janelas do design.
        general = {
          layout = "dwindle";
          gaps_in = 6;
          gaps_out = 14;
          border_size = 1;
          "col.active_border" = "rgb(3a4150)";
          "col.inactive_border" = "rgb(262c37)";
        };

        # TUIs abertas pelo shell (wifitui, btop, yazi…) usam a classe
        # fuleco.<nome> e abrem flutuando no centro.
        windowrule = [
          "match:class ^(fuleco\\..*)$, float on, size 1100 700, center on"
          # Diálogos (abrir/salvar arquivo, confirmações) flutuam no centro
          # sem mexer no tiling.
          "match:modal true, float on, center on"
          # Pop-ups do navegador (login, OAuth, extensões) nascem como
          # "Untitled - <navegador>"; janelas novas (Ctrl+N) são "New Tab".
          # Flutuam com o tamanho pedido pela página, sem mexer no tiling.
          "match:class ^(helium|chromium|google-chrome|brave-browser)$, match:initial_title ^(Untitled - .*)$, float on, center on"
          "match:class ^(xdg-desktop-portal-gtk|org\\.freedesktop\\.impl\\.portal\\..*)$, float on, center on, size 900 600"
          "match:title ^(Open File|Open Folder|Save File|Save As|Select .*|Choose .*|Abrir .*|Salvar .*|Selecionar .*|Escolher .*)$, float on, center on, size 900 600"
        ];

        # Cantos e blur no tom do Ayu; o blur aparece por trás de janelas
        # translúcidas, como o Ghostty.
        decoration = {
          rounding = 14;
          blur = {
            enabled = true;
            size = 6;
            passes = 2;
          };
        };

        # Animações curtas, com desaceleração no fim (estilo macOS).
        animations = {
          enabled = true;
          bezier = [
            "snap, 0.2, 0.9, 0.1, 1"
            "out, 0.3, 1, 0.4, 1"
          ];
          animation = [
            "windows, 1, 2.5, snap, popin 90%"
            "windowsOut, 1, 2, out, popin 90%"
            "border, 1, 3, out"
            "fade, 1, 2, out"
            "layers, 1, 2, snap, fade"
            "workspaces, 1, 2.5, snap, slide"
            "specialWorkspace, 1, 2.5, snap, slidevert"
          ];
        };

        dwindle = {
          preserve_split = true;
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
          "SUPER, RETURN, exec, ${hud "return"}$terminal"
          "SUPER SHIFT, RETURN, exec, ${hud "shift-return"}$browser"
          # Terminal já flutuando (cai na regra fuleco.*).
          "SUPER ALT, T, exec, ${hud "alt-t"}$terminal --class=fuleco.terminal"
          # Exposé e Alt+Tab do shell; o Alt+Tab usa atalho global (sem
          # passar por um processo) e confirma ao soltar o Alt (bindrt abaixo).
          "SUPER, TAB, exec, ${hud "tab"}${quickshellCtl} expo toggle"
          # App Exposé: as janelas do app em foco, de todos os workspaces.
          "SUPER, GRAVE, exec, ${hud "grave"}${quickshellCtl} expo app"
          "ALT, TAB, global, quickshell:alttab-next"
          "ALT SHIFT, TAB, global, quickshell:alttab-prev"
          "SUPER, SPACE, exec, ${hud "space"}${quickshellCtl} launcher toggle"
          # Layout do teclado (o HUD mostra qual ficou, via Keyboard.qml).
          "SUPER ALT, SPACE, exec, ${kbToggle}"
          "SUPER CTRL, V, exec, ${hud "ctrl-v"}${quickshellCtl} launcher clipboard"
          "SUPER CTRL, M, exec, ${hud "ctrl-m"}${quickshellCtl} monitors toggle"
          "SUPER CTRL, L, exec, ${lib.getExe pkgs.hyprlock}"
          "SUPER, Q, killactive"
          # Painéis do shell (o mesmo do clique na barra).
          "SUPER, W, exec, ${hud "w"}${quickshellCtl} shell toggle drawer"
          "SUPER, A, exec, ${hud "a"}${quickshellCtl} shell toggle control"
          "SUPER, N, exec, ${hud "n"}${quickshellCtl} shell toggle notifications"
          "SUPER, U, exec, ${hud "u"}${quickshellCtl} shell toggle ai"
          "SUPER, ESCAPE, exec, ${hud "esc"}${quickshellCtl} shell toggle power"
          "SUPER, SLASH, exec, ${quickshellCtl} shell toggle hud"
          "SUPER, F, fullscreen"
          "SUPER, F, exec, ${quickshellCtl} hud flash f"
          "SUPER, Q, exec, ${quickshellCtl} hud flash q"
          "SUPER, T, exec, ${quickshellCtl} hud flash t"
          "SUPER, T, togglefloating"
          "SUPER, H, exec, ${hud "h"}${quickshellCtl} shell floats"
          "SUPER, J, layoutmsg, togglesplit"
          "SUPER, left, movefocus, l"
          "SUPER, right, movefocus, r"
          "SUPER, up, movefocus, u"
          "SUPER, down, movefocus, d"
          # Reposiciona a janela no tiling.
          "SUPER CTRL, left, movewindow, l"
          "SUPER CTRL, right, movewindow, r"
          "SUPER CTRL, up, movewindow, u"
          "SUPER CTRL, down, movewindow, d"
        ]
        ++ workspaceBinds;

        # O OSD aparece sozinho quando volume ou brilho mudam.
        bindel = [
          ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          # O shell aplica o passo na hora (sem esperar a leitura do sysfs).
          ", XF86MonBrightnessUp, exec, ${quickshellCtl} brightness up"
          ", XF86MonBrightnessDown, exec, ${quickshellCtl} brightness down"
        ];

        # Caps/Num Lock: não consome a tecla, só avisa o HUD para ler os LEDs.
        bindln = [
          ", Caps_Lock, exec, ${quickshellCtl} hud locks"
          ", Num_Lock, exec, ${quickshellCtl} hud locks"
        ];

        bindl = [
          ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          ", XF86AudioPlay, exec, playerctl play-pause"
          ", XF86AudioNext, exec, playerctl next"
          ", XF86AudioPrev, exec, playerctl previous"
        ];

        # Soltar o Alt escolhe a janela do Alt+Tab (com ou sem Shift preso).
        bindrt = [
          "ALT, ALT_L, exec, ${quickshellCtl} alttab commit"
          "ALT SHIFT, ALT_L, exec, ${quickshellCtl} alttab commit"
        ];

        # Redimensiona a janela ativa (segurar repete).
        binde = [
          "SUPER SHIFT, left, resizeactive, -40 0"
          "SUPER SHIFT, right, resizeactive, 40 0"
          "SUPER SHIFT, up, resizeactive, 0 -40"
          "SUPER SHIFT, down, resizeactive, 0 40"
        ];

        # Super + arrastar move; Super+Shift + arrastar redimensiona.
        bindm = [
          "SUPER, mouse:272, movewindow"
          "SUPER SHIFT, mouse:272, resizewindow"
          "SUPER, mouse:273, resizewindow"
        ];

        # Touchpad: 3 dedos para os lados trocam de workspace, para cima abrem
        # o exposé e para baixo fecham (ou, sem nada aberto, abrem o App
        # Exposé do app em foco); com Super, 3 dedos arrastam a janela.
        gesture = [
          "3, horizontal, workspace"
          "3, up, dispatcher, exec, ${quickshellCtl} expo open"
          "3, down, dispatcher, exec, ${quickshellCtl} expo down"
          "3, swipe, mod: SUPER, move"
        ];
      };
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
      edge-swipe = {
        Unit = {
          Description = "Two-finger swipe from the touchpad's right edge";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${lib.getExe edgeSwipe} ${quickshellCtl} shell";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

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
