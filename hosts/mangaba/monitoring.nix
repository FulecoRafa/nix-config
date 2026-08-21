{ config, lib, ... }:

# Observabilidade e índice de acesso.
#
# O Glance é a porta de entrada do homelab: publicado em :443, então
# `https://mangaba.<tailnet>.ts.net` abre a lista de tudo que roda aqui — com
# link para quem tem UI e a lista dos CLIs para quem só existe no shell.
#
# Os títulos e categorias não moram aqui: cada módulo descreve o próprio
# serviço em `mangaba.tailscale.serve` e as próprias ferramentas em
# `mangaba.cli`. Assim, adicionar um serviço não exige lembrar de editar o
# dashboard.
#
# Gatus fica desligado por padrão: o widget `monitor` do Glance já cobre
# "está no ar?" sem mais um processo residente.
let
  cfg = config.mangaba.monitoring;
  kiosk = config.mangaba.kiosk;
  urls = config.mangaba.tailscale.urls;
  data = config.mangaba.storage.dataDir;

  ports = {
    glance = 8085;
    gatus = 8092;
  };

  # --- Índice: serviços com UI ---------------------------------------------
  services' = lib.filter (s: s.index) (
    lib.mapAttrsToList (name: s: s // { url = urls.${name}; }) config.mangaba.tailscale.serve
  );

  clis = lib.mapAttrsToList (name: c: c // { inherit name; }) config.mangaba.cli;

  # Categorias conhecidas primeiro, na ordem em que importam; qualquer outra
  # entra depois, em ordem alfabética.
  known = [
    "Mídia"
    "Música"
    "Apps"
    "Infra"
  ];
  orderCategories =
    items:
    let
      present = lib.unique (map (i: i.category) items);
    in
    (lib.filter (c: lib.elem c present) known)
    ++ lib.sort lib.lessThan (lib.subtractLists known present);

  byCategory = items: c: lib.filter (i: i.category == c) items;

  link =
    s:
    {
      inherit (s) title url;
    }
    // lib.optionalAttrs (s.description != "") { inherit (s) description; }
    // lib.optionalAttrs (s.icon != null) { inherit (s) icon; };

  bookmarks = {
    type = "bookmarks";
    title = "Serviços";
    groups = map (c: {
      title = c;
      links = map link (byCategory services' c);
    }) (orderCategories services');
  };

  # --- Índice: ferramentas de linha de comando -----------------------------
  # Não são links: existem só via SSH (`ssh mangaba`, autorização pela ACL do
  # tailnet). O widget serve para lembrar o que existe e como se chama.
  escapeHtml = lib.replaceStrings [ "&" "<" ">" ] [ "&amp;" "&lt;" "&gt;" ];

  # Descrição é texto, não markup: escapa tudo e só depois transforma os pares
  # de crase em <code>. Sem isso um `restore <id>` viraria tag e sumiria.
  markup =
    s:
    lib.concatImapStrings (i: part: if lib.mod i 2 == 0 then "<code>${part}</code>" else part) (
      lib.splitString "`" (escapeHtml s)
    );

  cliRow = c: ''
    <li>
      <div class="color-highlight"><code>${escapeHtml c.command}</code></div>
      <div class="size-h6 color-paragraph">${markup c.description}</div>
    </li>
  '';

  cliSection = c: ''
    <div class="margin-bottom-15">
      <div class="size-h6 uppercase color-highlight margin-bottom-3">${c}</div>
      <ul class="list list-gap-10">
        ${lib.concatMapStrings cliRow (byCategory clis c)}
      </ul>
    </div>
  '';

  cliWidget = {
    type = "html";
    title = "CLIs (via ssh mangaba)";
    source = lib.concatMapStrings cliSection (orderCategories clis);
  };

  site = title: url: {
    inherit title url;
  };

  serverStats = {
    type = "server-stats";
    servers = [
      {
        type = "local";
        name = "mangaba";
        # RAM é o gargalo desta máquina — deixar visível junto com o espaço
        # de /data.
        mountpoints = {
          "/" = { };
          ${data} = { };
        };
      }
    ];
  };

  # --- Painel da TV --------------------------------------------------------
  # Página separada porque a leitura é outra: de longe, sem ninguém para
  # clicar. Só o que se lê num relance — o que a máquina está fazendo, que dia
  # é hoje e o que falta fazer. Navegação escondida: não há mouse.
  painel = {
    name = "Painel";
    slug = kiosk.slug;
    hide-desktop-navigation = true;
    columns = [
      {
        size = "small";
        widgets = [
          {
            type = "clock";
            hour-format = "24h";
          }
          { type = "calendar"; }
        ];
      }
      {
        size = "full";
        widgets = [
          serverStats
          {
            type = "monitor";
            cache = "5m";
            title = "Serviços";
            sites = [
              (site "Jellyfin" urls.jellyfin)
              (site "Navidrome" urls.navidrome)
              (site "Vaultwarden" urls.vaultwarden)
              (site "Forgejo" urls.forgejo)
              (site "AdGuard" urls.adguard)
            ];
          }
        ];
      }
      {
        size = "small";
        widgets = [
          {
            type = "to-do";
            title = "Tarefas do dia";
            # As tarefas moram no localStorage do navegador, não no servidor:
            # quem edita é a própria TV, e o perfil do Chromium é persistente
            # (ver kiosk.nix). Abrir esta página de outra máquina mostra uma
            # lista vazia — é o comportamento do widget, não um bug.
            id = "mangaba-dia";
          }
        ];
      }
    ];
  };
in
{
  options.mangaba.monitoring.gatus.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Uptime monitor dedicado. Só vale se o widget `monitor` do Glance deixar
      de ser suficiente (histórico, SLA, alerta por endpoint).
    '';
  };

  options.mangaba.cli = lib.mkOption {
    default = { };
    description = ''
      Ferramentas de linha de comando do host, listadas no índice do Glance.
      Serviço sem UI não some do radar só porque não tem link.
    '';
    example = lib.literalExpression ''
      {
        beet = {
          description = "Tagging e organização da biblioteca de música.";
          category = "Música";
        };
      }
    '';
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            command = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = "Como invocar.";
            };
            description = lib.mkOption {
              type = lib.types.str;
              description = "Uma linha sobre o que a ferramenta faz.";
            };
            category = lib.mkOption {
              type = lib.types.str;
              default = "Infra";
              description = "Grupo no índice.";
            };
          };
        }
      )
    );
  };

  config = {
    services.glance = {
      enable = true;
      openFirewall = false;

      settings = {
        server = {
          host = "127.0.0.1";
          port = ports.glance;
        };

        pages = [
          {
            name = "Índice";
            columns = [
              {
                size = "full";
                widgets = [ bookmarks ];
              }
              {
                size = "small";
                widgets = [ cliWidget ];
              }
            ];
          }
          {
            name = "Status";
            columns = [
              {
                size = "small";
                widgets = [
                  { type = "calendar"; }
                  serverStats
                ];
              }
              {
                size = "full";
                widgets = [
                  {
                    type = "monitor";
                    cache = "5m";
                    title = "Mídia";
                    sites = [
                      (site "Jellyfin" urls.jellyfin)
                      (site "Navidrome" urls.navidrome)
                      (site "qBittorrent" urls.qbittorrent)
                      (site "Radarr" urls.radarr)
                      (site "Sonarr" urls.sonarr)
                      (site "Prowlarr" urls.prowlarr)
                      (site "Bazarr" urls.bazarr)
                    ];
                  }
                  {
                    type = "monitor";
                    cache = "5m";
                    title = "Apps";
                    sites = [
                      (site "Vaultwarden" urls.vaultwarden)
                      (site "Forgejo" urls.forgejo)
                      (site "Actual" urls.actual)
                      (site "ntfy" urls.ntfy)
                      (site "AdGuard" urls.adguard)
                    ];
                  }
                ];
              }
              {
                size = "small";
                widgets = [
                  {
                    type = "releases";
                    cache = "1d";
                    repositories = [
                      "jellyfin/jellyfin"
                      "glanceapp/glance"
                      "NixOS/nixpkgs"
                    ];
                  }
                ];
              }
            ];
          }
        ]
        ++ lib.optional kiosk.enable painel;
      };
    };

    mangaba.tailscale.serve = {
      # Em 443: `https://mangaba.<tailnet>.ts.net` sem porta cai aqui. Não se
      # lista no próprio índice.
      glance = {
        port = 443;
        target = "http://127.0.0.1:${toString ports.glance}";
        title = "Glance";
        category = "Infra";
        index = false;
      };
    }
    // lib.optionalAttrs cfg.gatus.enable {
      gatus = {
        port = ports.gatus;
        target = "http://127.0.0.1:${toString ports.gatus}";
        title = "Gatus";
        description = "Uptime dos serviços.";
        category = "Infra";
        icon = "di:gatus";
      };
    };

    services.gatus = lib.mkIf cfg.gatus.enable {
      enable = true;
      openFirewall = false;
      settings = {
        web = {
          address = "127.0.0.1";
          port = ports.gatus;
        };
        endpoints = lib.mapAttrsToList (name: url: {
          inherit name;
          group = "mangaba";
          inherit url;
          interval = "5m";
          conditions = [ "[STATUS] < 400" ];
        }) urls;
      };
    };
  };
}
