{
  config,
  lib,
  pkgs,
  ...
}:

# Painel na TV: um monitor plugado no servidor mostrando o Glance em tela
# cheia, sem teclado, sem mouse, sem desktop.
#
# A pilha é a menor que ainda funciona em Wayland puro: greetd faz o login
# automático, sway abre a sessão e o Chromium desenha a página. Sem Xwayland,
# sem barra, sem menu — se a máquina não tiver tela, basta
# `mangaba.kiosk.enable = false` e nada disso é construído.
#
# Por que sway e não cage (que é menor): cage clona a mesma imagem em todos os
# monitores. Aqui cada tela é uma entrada de `mangaba.kiosk.screens`, com URL
# própria, então dá para pendurar um segundo monitor com outra página só
# acrescentando um item na lista.
let
  cfg = config.mangaba.kiosk;

  stateDir = "/var/lib/mangaba-kiosk";

  # Um app_id por tela: é ele que o sway usa no `assign` para mandar cada
  # janela ao monitor certo, sem depender da ordem em que o Chromium sobe.
  appId = i: "mangaba-kiosk-${toString i}";

  screens = lib.imap1 (i: s: s // { index = i; }) cfg.screens;

  # Mesmo padrão do sync.nix: o Nix descreve, o runtime lê o JSON. Dá para
  # conferir o que a tela vai abrir sem ler Nix:  jq . /etc/mangaba/kiosk.json
  configFile = (pkgs.formats.json { }).generate "mangaba-kiosk.json" {
    screens = map (s: {
      inherit (s) index url zoom;
      appId = appId s.index;
      profile = "${stateDir}/${toString s.index}";
    }) screens;
  };

  launcher = pkgs.writeShellApplication {
    name = "mangaba-kiosk";
    runtimeInputs = [
      pkgs.jq
      pkgs.chromium
    ];
    text = ''
      config=''${1:-/etc/mangaba/kiosk.json}
      count=$(jq '.screens | length' "$config")

      for i in $(seq 0 $((count - 1))); do
        url=$(jq -r ".screens[$i].url" "$config")
        app_id=$(jq -r ".screens[$i].appId" "$config")
        profile=$(jq -r ".screens[$i].profile" "$config")
        zoom=$(jq -r ".screens[$i].zoom" "$config")

        # O perfil precisa sobreviver ao reboot: as tarefas do widget to-do do
        # Glance moram no localStorage deste diretório, não no servidor.
        mkdir -p "$profile"

        # Um crash do renderer não pode deixar a TV preta até alguém notar.
        (
          while true; do
            chromium \
              --ozone-platform=wayland \
              --kiosk \
              --app="$url" \
              --class="$app_id" \
              --user-data-dir="$profile" \
              --force-device-scale-factor="$zoom" \
              --no-first-run \
              --no-default-browser-check \
              --disable-infobars \
              --disable-session-crashed-bubble \
              --hide-scrollbars \
              --noerrdialogs \
              --password-store=basic || true
            sleep 5
          done
        ) &
      done

      wait
    '';
  };

  # Sem Xwayland: o Chromium desenha em Wayland nativo e ninguém mais vai
  # abrir janela aqui. Tira um servidor X inteiro do closure.
  sway = pkgs.sway.override {
    sway-unwrapped = pkgs.sway-unwrapped.override { enableXWayland = false; };
  };

  # Uma janela por workspace, um workspace por monitor. Sem borda, sem gap:
  # a página ocupa a tela inteira.
  swayConfig = pkgs.writeText "mangaba-kiosk-sway.conf" ''
    default_border none
    default_floating_border none
    gaps inner 0
    focus_follows_mouse no

    output * bg ${cfg.background} solid_color
    seat * hide_cursor 3000

    # Única saída manual da sessão (o resto se resolve por ssh).
    bindsym Mod4+Shift+q exit

    ${lib.concatMapStrings (s: ''
      ${lib.optionalString (s.output != null) "workspace ${toString s.index} output ${s.output}"}
      assign [app_id="${appId s.index}"] workspace ${toString s.index}
    '') screens}

    ${cfg.extraConfig}

    exec ${lib.getExe launcher}
  '';
in
{
  options.mangaba.kiosk = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Sessão gráfica de quiosque na tela do servidor. Desligar devolve a
        máquina ao estado headless (nenhum pacote gráfico é construído).
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "kiosk";
      description = ''
        Usuário que roda a sessão, com senha travada. Não é o `fuleco`: quem
        passa na frente da TV não deveria herdar a conta de quem administra o
        servidor.
      '';
    };

    slug = lib.mkOption {
      type = lib.types.str;
      default = "painel";
      description = ''
        Página do Glance montada para ser lida de longe (ver monitoring.nix).
      '';
    };

    url = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:${toString config.services.glance.settings.server.port}/${cfg.slug}";
      defaultText = lib.literalExpression ''"http://127.0.0.1:<porta do glance>/''${slug}"'';
      description = "URL padrão das telas que não definem a sua.";
    };

    background = lib.mkOption {
      type = lib.types.str;
      default = "#151719";
      description = "Cor do fundo enquanto o navegador não pintou nada.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Linhas extras de configuração do sway.";
    };

    screens = lib.mkOption {
      description = ''
        Uma entrada por monitor, na ordem em que estão pendurados. Com um
        monitor só, `output` pode ficar nulo; a partir do segundo, cada
        entrada precisa nomear a saída (`swaymsg -t get_outputs` lista os
        nomes, ex. `HDMI-A-1`).
      '';
      example = lib.literalExpression ''
        [
          { output = "HDMI-A-1"; }
          {
            output = "DP-1";
            url = "http://127.0.0.1:8085/";
            zoom = 1.5;
          }
        ]
      '';
      default = [ { } ];
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            output = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Nome da saída no sway. Nulo = a única tela.";
            };
            url = lib.mkOption {
              type = lib.types.str;
              default = cfg.url;
              defaultText = lib.literalExpression "config.mangaba.kiosk.url";
              description = "O que essa tela mostra.";
            };
            zoom = lib.mkOption {
              type = lib.types.numbers.positive;
              default = 1.5;
              description = ''
                Escala do conteúdo. O padrão é 1.5 porque o painel é lido de
                pé, a metros de distância, e não sentado a 60cm.
              '';
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.length screens < 2 || lib.all (s: s.output != null) screens;
        message = ''
          mangaba.kiosk: com mais de uma tela, cada entrada de `screens`
          precisa de `output` (veja `swaymsg -t get_outputs`), senão as
          janelas caem todas no mesmo monitor.
        '';
      }
    ];

    # De propósito sem `programs.sway.enable`: aquele módulo monta uma sessão
    # de desktop completa (portais XDG, dconf, gtk, terminal, lançador,
    # bloqueio de tela). Nada disso serve para uma página web em tela cheia.
    hardware.graphics.enable = true;

    # O greetd reinicia a sessão sozinha quando ela cai, então o painel volta
    # depois de um crash do sway sem ninguém intervir.
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${lib.getExe sway} --config ${swayConfig}";
        user = cfg.user;
      };
    };

    # Sem isso o console apaga sozinho depois de alguns minutos e a tela some
    # antes mesmo do sway assumir.
    boot.kernelParams = [ "consoleblank=0" ];

    users.groups.${cfg.user} = { };
    # Precisa ser usuário normal: o greetd abre a sessão pelo shell de login.
    # A senha fica travada — o acesso é físico à tela, não ao sistema.
    users.users.${cfg.user} = {
      isNormalUser = true;
      group = cfg.user;
      extraGroups = [
        "video"
        "input"
      ];
      home = stateDir;
      createHome = false;
      hashedPassword = "!";
    };

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0700 ${cfg.user} ${cfg.user} -"
    ];

    environment.etc."mangaba/kiosk.json".source = configFile;

    # `swaymsg` é a única forma de inspecionar a sessão de fora dela.
    environment.systemPackages = [ sway ];

    mangaba.cli.swaymsg = {
      command = "swaymsg -s /run/user/$(id -u ${cfg.user})/sway-ipc.*.sock -t get_outputs";
      description = ''
        Nomes das saídas de vídeo do painel, para preencher `output` em
        `mangaba.kiosk.screens`. `-t get_tree` mostra as janelas abertas.
      '';
    };

    # Sem fonte instalada o Glance renderiza caixas vazias. Uma família cobre
    # a interface inteira.
    fonts = {
      enableDefaultPackages = false;
      packages = [ pkgs.dejavu_fonts ];
    };
  };
}
