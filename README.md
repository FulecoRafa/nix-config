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
- TODO: **Server(_mangaba_)**: Server for hosting distributed services.
