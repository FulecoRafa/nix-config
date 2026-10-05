{ ... }:

# Lenovo ThinkPad T14 Gen 2i (20W100DQBO): i5-1145G7, Iris Xe, 16 GB,
# NVMe SSSTC 256 GB, Wi-Fi Intel AX201, áudio SOF.
# Layout do disco e perfil de GPU vêm de hosts/jaca/hardware.nix.
{
  jaca.hardware = {
    disk = "/dev/disk/by-id/nvme-SSSTC_CA5-8D256-Q79_SS0X49601L4BR24V51C8";
    gpu = "intel";
  };

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.kernelModules = [ "kvm-intel" ];
}
