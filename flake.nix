{
  description = "NixOS configuration for Personal Machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    nixos-hardware,
    ...
  }: {
    packages.x86_64-linux = let
      pkgs = import nixpkgs {system = "x86_64-linux";};
      nixos-anywhere = "${pkgs.nixos-anywhere}/bin/nixos-anywhere";
      nom = "${pkgs.nix-output-monitor}/bin/nom";
    in rec {
      apply = pkgs.writeShellScriptBin "apply" ''
        # Apply a system configuration (toplelevel) path to the current system.
        # This is like `nixos-rebuild switch` but for an arbitrary path to a
        #  nixosSystem toplevel.

        storePath=$(realpath $1)
        sudo nix-env -p /nix/var/nix/profiles/system --set $storePath
        sudo $storePath/bin/switch-to-configuration switch
      '';
      default = pkgs.writeShellScriptBin "default" ''
        # Build and apply the default system configuration of this flake.
        # This is like `nixos-rebuild switch` but for the default system of this flake.
        hostname=$(hostname)
        system=$(${nom} build ".#nixosConfigurations.$hostname.config.system.build.toplevel" --print-out-paths --no-link)
        ${apply}/bin/* $system
      '';
    };

    nixosConfigurations = rec {
      base-system = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit (self.inputs) nixos-hardware;};
        modules = [
          self.inputs.disko.nixosModules.disko
          ./base.nix
          ./desktop-cosmic.nix
          ./users.nix
          {
            networking.hostName = nixpkgs.lib.mkDefault "base-system";
          }
        ];
      };
      # System76 Adder WS (Laptop WorkStation)
      adder-ws = base-system.extendModules {
        modules = [
          ./adderws-config.nix
          {networking.hostName = "adder-ws";}
        ];
      };

      # Lenovo ThinkPad X1 Carbon 11th Gen
      thinkpad = base-system.extendModules {
        modules = [
          self.inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-11th-gen
          ./disko-laptop-ssd.nix
          {networking.hostName = "thinkpad";}
        ];
      };
    };
  };
}
