# Fuleco's Nix Config

This is the nix config for my systems, in different manners.

> [!WARNING] WIP
> This repository is a work in progress, use information here at your own risk.

## Dependencies

- [NixOS](https://nixos.org)
- [Home Manager](https://github.com/nix-community/home-manager)
- Other custom software I patched/built

## Folders

### Termapps

`home-manager` modules with cli applications. Devided by application

There are also bundles, which are just a collection of software that
are normally put together and are bundled in a file for easier imports

### Wayland

Configuration for having a Desktop environment and a GUI for running apps.

Today, this includes hyprland, waybar and other assists.

### Guiapps

Collection of GUI applications and there configurations, via `home-manager`.

This includes terminal emulator, browser and other applications.

### Hosts

Collections of different machine specifications

- **Terminal(_tamarindo_)**: a headless environment, just with terminal apps and ssh connection.
- TODO: **Desktop(_jaca_)**: my big desktop environment in home.
- **Macbook(_caju_)**: Apple Silicon managed with nix-darwin and Home Manager.
  CLI tools and supported GUI apps come from nixpkgs; Homebrew remains only as
  a declarative backend for casks and formulas that do not have a suitable Nix
  package. Apply it for the first time with:

  ```sh
  sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#caju
  ```

  Subsequent rebuilds use
  `sudo darwin-rebuild switch --flake .#caju`. Activation removes Homebrew
  packages not declared by Caju with `brew bundle cleanup --force`, but keeps
  application data and preferences (it does not use `zap`).
- TODO: **Laptop(_jabuticaba_)**: the linux laptop. Kinda like _jaca_,
but with battery optimizations
- **Server(_mangaba_)**: homelab. Media (Jellyfin, *arr, Recyclarr, qBittorrent,
Navidrome, beets, slskd), apps (Vaultwarden, Forgejo, ntfy, Actual), rsync sync jobs,
AdGuard Home, Glance and restic backups. Everything is exposed over the tailnet
with `tailscale serve`, so no service listens on a public port except the
torrent port and DNS.

`https://mangaba.<tailnet>.ts.net` (Glance, served on :443) is the entry point:
it indexes every service with a UI as a clickable link and lists the CLI-only
tools next to them. Both lists are generated — a service describes itself in
`mangaba.tailscale.serve` (`title`/`description`/`category`/`icon`) and a
command in `mangaba.cli`, so nothing has to be added to the dashboard by hand.

Host-specific modules live next to the host (`hosts/mangaba/*.nix`), since none
of them make sense on another machine. See `hosts/mangaba/plan.md` for the
reasoning behind the architecture choices.

Secrets use [sops-nix](https://github.com/Mic92/sops-nix) and are off by
default — `mangaba.secrets.enable = false` keeps the config evaluable without
any encrypted file, at the cost of restic, slskd and the Tailscale auth key
staying inactive.
