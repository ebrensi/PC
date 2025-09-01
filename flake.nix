{
  description = "NixOS configuration for System76 Adder with COSMIC Desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # COSMIC desktop environment
    nixos-cosmic = {
      url = "github:lilyinstarlight/nixos-cosmic";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixOS hardware configurations
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Disko for declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
  }: {
    packages.x86_64-linux = let
      pkgs = import nixpkgs {system = "x86_64-linux";};
    in {
      test = self.nixosConfigurations.adderWS.config.system.build.toplevel;
    };
    nixosConfigurations = {
      adderWS = nixpkgs.lib.nixosSystem {
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
        ];
      };
    };
  };
}
