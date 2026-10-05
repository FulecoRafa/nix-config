{
  fulecoLib,
  inputs,
  pkgs,
  root,
  ...
}:

# caju — MacBook Apple Silicon.
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    ./homebrew.nix
    ./packages.nix
  ];

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    optimise.automatic = true;
  };

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
  };

  networking = {
    hostName = "caju";
    computerName = "Caju";
    localHostName = "Caju";
  };

  time.timeZone = "America/Sao_Paulo";

  system = {
    primaryUser = "fuleco";
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
    stateVersion = 6;
  };

  programs.fish.enable = true;
  programs.zsh = {
    enable = true;
    # O compinit roda no .zshrc do Home Manager.
    enableGlobalCompInit = false;
  };
  users.users.fuleco = {
    home = "/Users/fuleco";
    shell = pkgs.zsh;
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit inputs root fulecoLib;
    };
    users.fuleco = import ./home.nix;
  };
}
