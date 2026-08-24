{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.jaca.hardware;
in
{
  imports = [ inputs.disko.nixosModules.disko ];

  options.jaca.hardware = {
    disk = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/dev/disk/by-id/nvme-SAMSUNG_EXAMPLE";
      description = ''
        Caminho persistente do disco físico. Enquanto for null, nenhuma tabela de
        partições é declarada; use exclusivamente um caminho em /dev/disk/by-id.
      '';
    };

    swapSize = lib.mkOption {
      type = lib.types.str;
      default = "16G";
      description = "Tamanho do swapfile criado pelo Disko.";
    };

    gpu = lib.mkOption {
      type = lib.types.enum [
        "auto"
        "amd"
        "intel"
        "nvidia"
      ];
      default = "auto";
      description = "Perfil de GPU; auto mantém somente a configuração genérica.";
    };

    nvidiaOpen = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Usa os módulos de kernel abertos no perfil NVIDIA.";
    };
  };

  config = lib.mkMerge [
    {
      boot.loader.systemd-boot.enable = lib.mkDefault true;
      boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

      hardware.enableRedistributableFirmware = true;
      services.fstrim.enable = true;

      warnings = lib.optional (cfg.disk == null) ''
        jaca.hardware.disk ainda não foi definido. O layout físico não será
        gerado até que um /dev/disk/by-id exato seja informado.
      '';
    }

    (lib.mkIf (cfg.disk != null) {
      disko.devices.disk.main = {
        type = "disk";
        device = cfg.disk;
        content = {
          type = "gpt";
          partitions = {
            esp = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            system = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/var" = {
                    mountpoint = "/var";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/swap" = {
                    mountpoint = "/swap";
                    mountOptions = [ "noatime" ];
                    swap.swapfile.size = cfg.swapSize;
                  };
                };
              };
            };
          };
        };
      };
    })

    (lib.mkIf (cfg.gpu == "amd") {
      boot.initrd.kernelModules = [ "amdgpu" ];
      hardware.cpu.amd.updateMicrocode = true;
    })

    (lib.mkIf (cfg.gpu == "intel") {
      hardware.cpu.intel.updateMicrocode = true;
      hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
    })

    (lib.mkIf (cfg.gpu == "nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia = {
        modesetting.enable = true;
        open = cfg.nvidiaOpen;
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };
      environment.sessionVariables = {
        GBM_BACKEND = "nvidia-drm";
        LIBVA_DRIVER_NAME = "nvidia";
        NVD_BACKEND = "direct";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      };
    })
  ];
}
