{
  description = "NixOS configuration for Personal Machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-cosmic = {
      url = "github:lilyinstarlight/nixos-cosmic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: {
    packages.x86_64-linux = let
      pkgs = import nixpkgs {system = "x86_64-linux";};
    in {
      test = self.nixosConfigurations.adder-ws.config.system.build.toplevel;
    };
    nixosConfigurations = {
      adder-ws = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.inputs.disko.nixosModules.disko
          self.inputs.nixos-cosmic.nixosModules.default
          ./disko-laptop-ssd.nix
          ./base.nix
          ./users.nix
          ./system76.nix
          ./desktop-cosmic.nix
          ./adderWS-config.nix
          {networking.hostName = "adder-ws";}
        ];
      };
    };
  };
}
