{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    helix.url = "github:fulecorafa/helix/feat/breadcrumbs-popup";
    helix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = {nixpkgs, home-manager, ...}@inputs: {
    nixosConfigurations.terminal = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        root = ./.;
      };
      modules = [./hosts/terminal];
    };
    nixosConfigurations.mangaba = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        root = ./.;
      };
      modules = [./hosts/mangaba];
    };
    homeConfigurations = {
      "fuleco@tamarindo" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {
          inherit inputs;
          root = ./.;
        };
        modules = [./hosts/terminal/home/fuleco/home-module.nix];
      };
    };
  };

}
