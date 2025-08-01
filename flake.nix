{
  description = "NixOS configuration for System76 Adder with COSMIC Desktop";

  inputs = {
    # Use nixos-unstable for the latest COSMIC support
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
    nixos-cosmic,
    nixos-hardware,
    disko,
  }: {
    nixosConfigurations = {
      # Change "adder-nixos" to match your hostname in configuration.nix
      adder-nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          # Disko for declarative disk management
          disko.nixosModules.disko

          # COSMIC desktop support
          nixos-cosmic.nixosModules.default

          # System76 hardware support
          nixos-hardware.nixosModules.system76

          # Disk configuration
          ./disko-config-simple.nix

          # Your main configuration
          ./configuration.nix

          # Additional configuration for COSMIC setup
          {
            nix.settings = {
              substituters = [
                "https://cosmic.cachix.org/"
              ];
              trusted-public-keys = [
                "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
              ];
            };
          }
        ];
      };
    };
  };
}
