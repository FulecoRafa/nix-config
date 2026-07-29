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
- TODO: **Macbook(_caju_)**: the fake apple infecting the real Apple.
- TODO: **Laptop(_jabuticaba_)**: the linux laptop. Kinda like _jaca_,
but with battery optimizations
- **Server(_mangaba_)**: homelab. Media (Jellyfin, *arr, qBittorrent, Navidrome,
beets, slskd), apps (Vaultwarden, Forgejo, ntfy, Actual), rsync sync jobs,
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
