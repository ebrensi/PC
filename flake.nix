{
  description = "NixOS configuration for Personal Machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    ...
  }: {
    packages.x86_64-linux = let
      pkgs = import nixpkgs {system = "x86_64-linux";};
      nixos-anywhere = "${pkgs.nixos-anywhere}/bin/nixos-anywhere";
      nom = "${pkgs.nix-output-monitor}/bin/nom";
    in rec {
      test = pkgs.writeShellScriptBin "install" ''
        flakePath=$1
        ${nixos-anywhere} --flake "$flakePath" --vm-test
      '';
      apply = pkgs.writeShellScriptBin "apply" ''
        # Apply a system configuration (toplelevel) path to the current system.
        # This is like `nixos-rebuild switch` but for an arbitrary built system given as a store path.
        storePath=$(realpath $1)
        sudo nix-env -p /nix/var/nix/profiles/system --set $storePath
        sudo $storePath/bin/switch-to-configuration switch
      '';
      default = pkgs.writeShellScriptBin "default" ''
        # Build and apply the default system configuration of this flake.
        # This is like `nixos-rebuild switch` but for the default system of this flake.
        system=$(${nom} build .#nixosConfigurations.adder-ws.config.system.build.toplevel --print-out-paths --no-link)
        ${apply}/bin/* $system
        # echo "$system built!"
      '';
    };
    nixosConfigurations = rec {
      adder-ws = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with self.inputs.nixos-hardware.nixosModules; [
          self.inputs.disko.nixosModules.disko
          system76
          common-cpu-intel
          common-gpu-intel
          # common-gpu-nvidia
          common-gpu-nvidia-sync
          common-pc-ssd
          common-pc-laptop
          common-hidpi
          ./disko-laptop-ssd.nix
          ./base.nix
          ./users.nix
          ./desktop-cosmic.nix
          ./adderws-config.nix
          ./adderws.hardware.nix
          {
            networking.hostName = "adder-ws";
          }
        ];
      };
    };
  };
}
