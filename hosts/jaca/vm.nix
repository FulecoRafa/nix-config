{
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];

  nixpkgs.hostPlatform = lib.mkForce "aarch64-linux";
  networking.hostName = lib.mkForce "jaca-vm";

  jaca.hardware = {
    disk = null;
    gpu = "auto";
  };

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  virtualisation = {
    cores = 4;
    diskSize = 32768;
    graphics = true;
    memorySize = 6144;
  };

  # Credencial deliberadamente descartável, exclusiva do perfil de VM.
  users.users.fuleco.initialPassword = "fuleco";
}
