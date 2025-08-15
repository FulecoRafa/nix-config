{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    helix.url = "github:fulecorafa/helix/feat/breadcrumbs-popup";
    helix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = {nixpkgs, ...}@inputs: {
    nixosConfigurations.terminal = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [./hosts/terminal];
    };
  };
}
