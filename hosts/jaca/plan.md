# Jaca — plano do desktop

Este documento acompanha as decisões do desktop `jaca`. Ele toma o Omarchy
como referência de produto (um sistema coeso, operável por teclado e com bons
defaults), não como uma lista de pacotes a copiar.

Temas, paleta, tipografia e acabamento visual ficam fora desta etapa.

## Princípio: poucas stacks de interface

Stacks aceitas inicialmente:

| Stack | Papel |
| --- | --- |
| Web/Chromium | Helium e aplicações web instaláveis |
| Terminal | Ghostty e TUIs |
| Qt/QML | Quickshell e aplicações próprias |
| Tauri | Aplicações próprias ou de terceiros quando Web não bastar |

GTK não é uma stack escolhida para novas aplicações. Bibliotecas GTK que
cheguem como dependência operacional de componentes do sistema não tornam GTK
uma stack de produto; ainda assim, cada aplicação GTK deve ser deliberada.

## O que aproveitar do Omarchy

A versão atual em desenvolvimento do Omarchy concentra em um único processo
Quickshell:

- barra e indicadores de workspaces;
- launcher e menu de sistema;
- notificações e histórico;
- OSD de volume e brilho;
- lock screen;
- painéis de áudio, rede, Bluetooth, tela, energia, calendário, mídia e tray.

Esse desenho substitui a combinação anterior de Waybar, Walker, Mako e outros
processos. Para `jaca`, a mesma consolidação é mais importante que reproduzir a
interface do Omarchy. O shell será nosso e poderá começar pequeno.

Outras ideias que valem preservar:

- compositor Wayland com navegação por teclado e atalhos descobríveis;
- defaults XDG declarativos por função (browser, terminal, editor etc.);
- web apps como entradas `.desktop`, sem instalar um cliente Electron para
  cada serviço;
- clipboard com histórico, screenshots/gravação e compartilhamento como
  capacidades do desktop;
- ferramentas de sistema preferencialmente em TUI;
- aplicações opcionais não fazem parte do núcleo do sistema.

## Comparação com o repositório atual

### Já existe e deve ser reaproveitado

- Helium empacotado em `guiapps/helium`;
- fábrica declarativa de web apps em `guiapps/local-web-apps.nix`;
- Ghostty em `termapps/ghostty`;
- Helix, Nushell, Fish, Zellij, Jujutsu, Fastfetch e utilitários CLI;
- `fuchico`, aplicação própria;
- helpers para arquivos `.desktop` em `lib`.

### Deve ser reaproveitado e evoluído

- `guiapps/default.nix` agrega aplicações, aparência GTK/Qt, Ghostty e Espanso;
  podemos manter o que já existe e selecionar dele o que for útil para `jaca`;
- `guiapps/appearance.nix` instala e configura GTK e KDE/Breeze. Aparência não
  será redesenhada agora: a configuração existente pode ser usada como base e
  editada posteriormente;
- o README ainda descreve Hyprland + Waybar, mas esses módulos não existem no
  estado atual do repositório. `jaca` usará Hyprland com Quickshell puro, sem
  Waybar;
- a base NixOS e Home Manager de `jaca` agora existe; o hardware físico fica
  parametrizado até levantarmos os identificadores e modelos da máquina.

## Núcleo proposto

Confirmado:

- NixOS + Home Manager;
- sessão Wayland;
- Helium como browser e runtime de web apps;
- Ghostty como terminal;
- Quickshell como shell Qt/QML único;
- web apps individuais e Tauri são alternativas igualmente válidas para a
  experiência de uma aplicação. Tauri será usado quando precisarmos de backend
  nativo ou integração que o browser não ofereça;
- evitar Electron e clientes nativos redundantes quando o serviço web for
  suficiente;
- não escolher file manager existente por enquanto; o explorador de arquivos
  é candidato a aplicação própria;
- Hyprland como compositor;
- Hyprlock para bloqueio de sessão;
- OBS Studio para gravação;
- Docker como parte obrigatória do ambiente de desenvolvimento.
- Steam como base para jogos, com Proton-GE, Protontricks, Steam Input no
  Wayland, GameMode, Gamescope e MangoHud. Essa base é ativada somente no host
  x86_64; `jaca-vm` em ARM continua útil para avaliar o restante do desktop.
- KDE Connect para parear o celular usando a stack Qt existente. O daemon roda
  junto da sessão gráfica para sincronizar clipboard, notificações e arquivos;
  o módulo NixOS abre somente o intervalo TCP/UDP exigido pelo protocolo.
- screenshots usam Hyprshot para captura e Gradia para edição/anotação. Um
  fluxo separado usa Tesseract em português e inglês para produzir PDFs
  pesquisáveis e abri-los no visualizador padrão.

### Workspaces

A ordem semântica inicial é:

| Posição | Função |
| --- | --- |
| 1 | browser |
| 2 | trabalho principal |
| 3 | produtos do trabalho e ferramentas necessárias para eles |
| 4 | redes |
| 5 | notícias |
| 6 até penúltimo | funções adicionais que surgirem |
| último | música e aplicações de background |

O número total de workspaces continua aberto. A configuração deverá expressar
o workspace de música como "último", em vez de espalhar um número fixo pelos
atalhos e regras de janela.

A decidir, nesta ordem:

1. número total de workspaces e funções adicionais;
2. escopo do primeiro Quickshell. Podemos criar stubs de barra, launcher,
   notificações, OSD e lock inspirados fortemente no macOS enquanto o design é
   desenvolvido;
3. autenticação declarativa do usuário físico; o login usa greetd/tuigreet e
   inicia Hyprland via UWSM, enquanto o bloqueio será feito pelo Hyprlock;
4. backend do histórico de clipboard, integrado ao launcher;
5. detalhes do ambiente de desenvolvimento. Aplicações confirmadas: Fuchico,
   VS Code, Zed, Helix, TUIs usuais e Docker; ambientes de projeto virão do
   Nix;
6. Discord nativo está confirmado; YouTube Music, WhatsApp e Telegram serão
   escolhidos entre Web/Tauri/nativo por caso;
7. aplicações próprias.

Os demais sites serão abertos pelo Helium. O launcher deverá consumir os
favoritos do browser, evitando manter atalhos e favoritos em dois catálogos.
Portais e file picker serão tratados junto do futuro explorador de arquivos.

## Catálogo Omarchy: usar como checklist, não como baseline

| Função no Omarchy | Direção para `jaca` |
| --- | --- |
| Chromium e web apps | Helium e `localWebApps` |
| Foot, com Ghostty opcional | Ghostty |
| Omarchy Shell em Quickshell | Quickshell próprio, incremental |
| Nautilus | nenhuma escolha; explorar app próprio |
| Neovim e editores opcionais | Fuchico, VS Code, Zed e Helix |
| Obsidian | avaliar web app ou manter nativo apenas se necessário |
| imv, mpv e visualizador de PDF | Helium para PDF; avaliar imv e mpv para imagem e vídeo |
| Lazygit | não incluir; usar Jujutsu sem TUI |
| Lazydocker, btop, dua | incluir btop; futuras interfaces web para disco e Docker |
| LocalSend | executar no servidor e disponibilizar pela tailnet |
| Pinta e Disks | Gradia para screenshots; avaliar editor geral depois e não incluir Disks |
| Docker | requisito do ambiente de desenvolvimento |
| Apps experimentais do Flathub | Flatpak Lab por usuário, com remoção automática |
| Rede privada entre dispositivos | cliente Tailscale persistente, com login interativo inicial |
| Comunicação por voz e comunidades | cliente oficial do Discord via nixpkgs |

## Decisões

Nenhuma decisão pendente deve ser inferida só porque o Omarchy a tomou. Cada
grupo de aplicações será escolhido em uma conversa curta e registrado aqui
antes de entrar na configuração do host.

## Estado da implementação

A primeira base funcional está implementada. O host contém apenas sua
composição e suas decisões físicas; configurações reutilizáveis vivem com as
aplicações:

- `default.nix`: identidade NixOS, NetworkManager, usuário e composição dos
  bundles compartilhados de desktop, terminal e Docker;
- `home.nix`: identidade Home Manager e parâmetros próprios do Jaca;
- `hardware.nix`: UEFI com systemd-boot, layout GPT/Btrfs opcional via Disko e
  perfis selecionáveis para GPU AMD, Intel e NVIDIA;
- `guiapps/linux-desktop.system.bundle.nix`: Hyprland/UWSM, PipeWire,
  Bluetooth, login, KDE Connect e Steam no nível do sistema;
- `guiapps/linux-desktop.home.bundle.nix`: aplicações da sessão, associações
  XDG, Quickshell, KDE Connect e painel de uso das ferramentas de IA;
- `guiapps/hyprland/`: atalhos, Hyprlock, clipboard, greetd, Quickshell,
  gerenciador declarativo e interativo de monitores e fluxo de screenshots
  com Hyprshot, Gradia e OCR para PDF via Tesseract;
- `guiapps/steam/system.nix`: Steam e correções usuais da comunidade NixOS,
  incluindo runtime 32-bit, Proton-GE, Protontricks, extest, GameMode,
  Gamescope, MangoHud, suporte a controles e transferências na rede local;
- `termapps/ai-usage/`: instala Claude Code e Codex e fornece à barra somente
  dados sanitizados, sem expor OAuth tokens ao Quickshell;
- `guiapps/kdeconnect/`: aplicação, firewall e daemon persistente da sessão;
- `guiapps/discord.nix`: cliente oficial do Discord, atualizado exclusivamente
  pelo Nix e executado em Wayland pelo wrapper do nixpkgs;
- `termapps/docker/system.nix`: daemon, limpeza automática e acesso do usuário;
- `services/flatpak-lab/`: fornece `app-try` para executar temporariamente IDs,
  URLs do Flathub ou arquivos `.flatpakref`; remove app, dados e runtimes não
  usados ao fechar e recupera limpezas interrompidas no próximo login;
- `services/tailscale-client/`: mantém o Jaca conectado ao tailnet, prepara o
  roteamento de cliente e preserva o login fora do Nix store;
- `vm.nix`: perfil descartável `jaca-vm` em aarch64-linux para validar o host
  numa VM Linux em Apple Silicon.

Os workspaces `1` a `5` representam as funções fixas já decididas; `6` é, por
enquanto, o último workspace e aparece como `M`. A quantidade vem de
`hyprlandDesktop.workspaceCount`, declarada pelo host e exportada pelo módulo
compartilhado para o Quickshell.

Os atalhos de screenshot preservam `Print`, `Super+Print` e
`Super+Shift+Print` para capturas rápidas. `Ctrl+Print` e
`Super+Ctrl+Print` enviam região ou janela ao Gradia; `Alt+Print` e
`Super+Alt+Print` geram um PDF pesquisável de região ou janela em
`Documentos/Screenshots/OCR`.

O host físico continua exposto como `nixosModules.jaca`; o perfil testável é
`nixosConfigurations.jaca-vm`. Para expor e instalar
`nixosConfigurations.jaca`, ainda faltam dados que não devem ser inventados:

- `/dev/disk/by-id` exato do disco de destino e decisão sobre criptografia;
- fabricante/modelo da GPU para selecionar o perfil já implementado;
- nomes dos conectores, resolução, frequência, escala, posição e rotação dos
  monitores;
- autenticação inicial do usuário.

O layout proposto reserva 1 GiB para ESP e usa o restante como Btrfs com
subvolumes separados para `/`, `/nix`, `/home`, `/var` e swapfile. Como
`jaca.hardware.disk` é `null` por padrão, avaliar ou executar a VM não aciona
operações de particionamento. A execução do Disko só deve ocorrer depois da
conferência presencial do identificador do disco.

O Helix agora vem do mesmo nixpkgs do sistema/Home Manager; a trilha própria
de input e pacote foi removida.

GameMode, MangoHud e Gamescope não são injetados globalmente nos jogos, pois
isso pode piorar compatibilidade e anti-cheat. Quando um jogo precisar, as
opções de inicialização usuais são, respectivamente, `gamemoderun %command%`,
`mangohud %command%` e `gamescope -f -- %command%`; elas podem ser combinadas
por jogo.

Os elementos visuais atuais são deliberadamente neutros e funcionam como
stubs; não representam o tema ou o design final.
