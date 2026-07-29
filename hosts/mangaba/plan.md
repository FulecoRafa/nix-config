# Homelab — spec de implementação (NixOS)

Contexto para retomar o trabalho em outra sessão. Decisões já tomadas; o que
falta é escrever a configuração.

## Hardware e restrições

- i7 3ª geração (Ivy Bridge), 8GB RAM. **RAM é o gargalo, não CPU.**
- Quick Sync de 3ª gen acelera apenas H.264 e MPEG-2. Sem HEVC/VP9/AV1 em
  hardware.
- Sem renderização de vídeo. Carga principal é streaming Jellyfin.
- Orçamento alvo: ~4GB em uso, ~3GB livres para page cache.

## Decisões de arquitetura

| Decisão | Escolha | Motivo |
|---|---|---|
| Orquestração | **Nix puro, sem k3s** | Maioria dos serviços tem módulo nativo; k8s em nó único é overhead sem ganho |
| Containers | `virtualisation.oci-containers` (Podman) | Só para o que não tem módulo nativo |
| Rede/acesso | Tailscale + `tailscale serve` | HTTPS com cert válido sem ingress, cert-manager ou DNS challenge |
| SSH | Tailscale SSH | Elimina gestão de `authorized_keys`; ACL do tailnet vira autorização |
| Dashboard | **Glance** | Leve (Go), YAML, e já cobre observabilidade |
| Observabilidade | Widgets nativos do Glance | Beszel só se precisar de histórico + alertas por threshold |
| Backup | **restic** via `services.restic.backups` | Snapshots versionados, dedup, criptografia, retenção |
| Sync | ~~Syncthing~~ → rsync em timer de 15min (não é backup) | Replicação entre máquinas apenas |

## Serviços — verificar módulo nativo em search.nixos.org

Preferir módulo nativo sempre que existir (config tipada, hardening systemd,
rollback junto com o sistema).

**Infra**
- `services.tailscale` — subnet router, exit node, MagicDNS, ACLs com tags
- `services.adguardhome` — DNS + ad-block da rede
- `services.glance` — dashboard
- `services.restic.backups` — timer systemd para HDD externo + bucket remoto
- ~~`services.syncthing`~~ — trocado por rsync em timer (`sync.nix`)

**Mídia — vídeo**
- `services.jellyfin` — VAAPI só para H.264, priorizar direct play
- `services.prowlarr` — indexadores
- `services.radarr` / `services.sonarr`
- `services.bazarr` — legendas (OpenSubtitles.com + Podnapisi, score mínimo
  alto, upgrade ligado). Alternativa leve: plugin OpenSubtitles do Jellyfin
- Cliente de download: **qBittorrent-nox** (torrent — decidido). Transmission
  é a alternativa mais leve se a RAM apertar

**Mídia — música**
- `services.navidrome` — servidor Subsonic
- **beets** — tagging/capa/organização; config YAML declarada no Nix.
  Plugins: `fetchart`, `embedart`, `chroma`/`acoustid`, `lyrics`,
  `replaygain`, `scrub`
- slskd ou Lidarr como aquisição (Lidarr tem matching fraco)

**Apps**
- `services.vaultwarden`
- `services.forgejo`
- ~~`services.atuin`~~ — descartado na implementação
- `services.ntfy-sh`
- `services.gatus` — avaliar se o widget `monitor` do Glance já basta
- Actual Budget, Karakeep — provavelmente via OCI container

## Layout de disco (crítico para torrent)

Downloads e biblioteca **precisam estar no mesmo filesystem**, sob uma raiz
única, senão o Radarr/Sonarr faz cópia em vez de hardlink — dobra o uso de
disco e quebra o seed.

```
/data/
  torrents/
    movies/
    tv/
    music/
  media/
    movies/
    tv/
    music/
```

Um único mount. Nada de bind mounts separados por serviço.

Permissões: criar `users.groups.media`, colocar qBittorrent e todos os `*arr`
nesse grupo, umask 002. Atenção com os módulos que usam `DynamicUser` — pode
ser necessário `SupplementaryGroups` no override do systemd.

Se o filesystem for btrfs, desabilitar CoW no diretório de downloads
(`chattr +C` antes de gravar qualquer coisa) — escrita aleatória de torrent
fragmenta muito.

## Pontos de atenção

- **BIOS:** habilitar "iGPU Multi-Monitor" (ou equivalente) para expor
  `/dev/dri/renderD128` sem monitor conectado. Sem isso, não há VAAPI.
- **Naming scheme do TRaSH Guides** nos templates de Radarr/Sonarr. É o que
  faz o Jellyfin acertar metadados e capa automaticamente.
- **Syncthing** escala com número de arquivos, não tamanho — não apontar para
  a biblioteca de mídia.
- **Karakeep** passa de 400MB com o Meilisearch junto, mesmo sem ML. É o app
  mais caro proporcionalmente ao valor.
- **Nix store** cresce; agendar garbage collect
  (`nix.gc.automatic` + `nix.optimise.automatic`).

## Estrutura de flake sugerida

```
flake.nix
hosts/
  homelab/
    default.nix
    hardware-configuration.nix
modules/
  tailscale.nix
  media.nix        # jellyfin + *arr + bazarr + download client
  music.nix        # navidrome + beets
  apps.nix         # vaultwarden, forgejo, atuin, ntfy
  monitoring.nix   # glance + agent
  backup.nix       # restic
secrets/           # sops-nix ou agenix
```

Definir estratégia de segredos antes de escrever os módulos — API keys de
Prowlarr/Radarr/Bazarr, token do Glance agent, senha do repo restic e chave
do Tailscale não podem ir para o Nix store em texto puro.

## Ideia paralela — dashboard TUI

Grafatui (Rust/Ratatui, importa JSON de dashboard do Grafana) já cobre boa
parte. Nicho ainda aberto: multi-host + painéis de comando arbitrário.
Arquitetura pensada:

```
glance-agent / node_exporter  (por máquina)
        ↓
VictoriaMetrics single-node   (~100MB, API Prometheus)
        ↓
TUI em Ratatui                (PromQL + widgets custom via shell)
```

Discovery de hosts de graça via `tailscale status --json`.