{
  fulecoLib,
  inputs,
  lib,
  pkgs,
  root,
  ...
}:

# jaca — desktop principal x86_64.
# Hardware específico permanece parametrizado até levantarmos os dados físicos.
{
  imports = [
    ./hardware.nix
    inputs.home-manager.nixosModules.home-manager
    (root + /guiapps/linux-desktop.system.bundle.nix)
    (root + /termapps/docker/system.nix)
    (root + /termapps/system.bundle.nix)
  ];

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    optimise.automatic = true;
  };

  nixpkgs = {
    hostPlatform = lib.mkDefault "x86_64-linux";
    config.allowUnfree = true;
  };

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  networking = {
    hostName = "jaca";
    networkmanager.enable = true;
  };

  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "en_US.UTF-8";

  programs.zsh = {
    enable = true;
    # O compinit roda no .zshrc do Home Manager.
    enableGlobalCompInit = false;
  };
  environment.pathsToLink = [ "/share/zsh" ];

  dockerHost.enable = true;

  users.users.fuleco = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "video"
      "wheel"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit inputs root fulecoLib;
    };
    users.fuleco = import ./home.nix;
  };

  system.stateVersion = "25.05";
}
