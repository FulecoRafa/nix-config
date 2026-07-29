{ config, lib, pkgs, modulesPath, inputs, ... }:

# i7 3ª geração (Ivy Bridge), 8GB RAM.
#
# Dois discos: sda para o sistema, sdb inteiro para /data. Downloads e
# biblioteca precisam ficar no mesmo filesystem para o hardlink dos *arr
# funcionar — daí um único mount em /data, sem subdividir.
{
  imports = [
    inputs.disko.nixosModules.disko
  ];

  disko.devices.disk = {
    main = {
      device = lib.mkDefault "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02";
          };
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              subvolumes = {
                "/root" = {
                  mountOptions = [ "compress=zstd" ];
                  mountpoint = "/";
                };
                "/nix" = {
                  mountOptions = [ "compress=zstd" "noatime" ];
                  mountpoint = "/nix";
                };
                "/home" = {
                  mountOptions = [ "compress=zstd" ];
                  mountpoint = "/home";
                };
                "/var" = {
                  mountOptions = [ "compress=zstd" "noatime" ];
                  mountpoint = "/var";
                };
                "/swap" = {
                  mountOptions = [ "noatime" ];
                  mountpoint = "/swap";
                  # 8GB de RAM com Jellyfin + Postgres: swap real para o que
                  # está ocioso, e zram (ver default.nix) para o resto.
                  swap.swapfile = {
                    size = lib.mkDefault "4G";
                    path = "swapfile";
                  };
                };
              };
            };
          };
        };
      };
    };

    data = {
      device = lib.mkDefault "/dev/sdb";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          data = {
            size = "100%";
            content = {
              type = "btrfs";
              # Sem compressão: mídia já vem comprimida, compactar de novo só
              # gasta CPU que essa máquina não tem sobrando.
              subvolumes = {
                "/data" = {
                  mountOptions = [ "noatime" ];
                  mountpoint = "/data";
                };
              };
            };
          };
        };
      };
    };
  };

  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "ehci_pci"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
