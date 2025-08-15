{ config, lib, pkgs, inputs, root, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./home/fuleco/homemanager.nix
    (root + /termapps/system.bundle.nix)
  ];

  environment.variables = {
    EDITOR = "hx";
    COLORTERM = "truecolor";
  };

  # disko.devices.disk.main.content.partitions.root.content.subvolumes."/swap".swap.swapfile.size = "2G";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "terminal"; # Define your hostname.
  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  time.timeZone = "America/Sao_Paulo";

  i18n.defaultLocale = "en_US.UTF-8";

  users.users.fuleco = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    initialPassword = "correcthorsebatterystaple";
    packages = with pkgs; [
    ];
  };

  services.openssh = {
    enable = true;
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?

}

