{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    fuchico.url = "github:FulecoRafa/fuchico";
    fuchico.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    let
      fulecoLib = import ./lib { inherit (nixpkgs) lib; };
    in
    {
      lib = fulecoLib;

      nixosConfigurations.terminal = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs fulecoLib;
          root = ./.;
        };
        modules = [ ./hosts/terminal ];
      };
      nixosConfigurations.mangaba = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs fulecoLib;
          root = ./.;
        };
        modules = [ ./hosts/mangaba ];
      };
      darwinConfigurations.caju = inputs.nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs fulecoLib;
          root = ./.;
        };
        modules = [ ./hosts/caju ];
      };
      homeConfigurations = {
        "fuleco@tamarindo" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs fulecoLib;
            root = ./.;
          };
          modules = [ ./hosts/terminal/home/fuleco/home-module.nix ];
        };
      };
    };

}
