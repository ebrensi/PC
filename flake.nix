{
  description = "NixOS configuration for Personal Machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
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
      nom = "${pkgs.nix-output-monitor}/bin/nom";
      installer-base = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = ["${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"];
      };
      mkInstaller = hostname:
        (installer-base.extendModules {
          modules = [./install-script.nix];
          specialArgs = {systemToInstall = self.nixosConfigurations.${hostname};};
        }).config.system.build.isoImage;
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

      # TODO: generalize this to all nixosConfigurations
      #  maybe with a loop and using `lib.attrNames self.nixosConfigurations`?
      # Note that we can make installers without getting hardware info first,
      #  because we have hardware (mostly) pre-configured via nixos-hardware.
      thinkpad-offline-installer-iso = mkInstaller "thinkpad";
      adder-ws-offline-installer-iso = mkInstaller "adder-ws";

      thinkpad = self.nixosConfigurations.thinkpad.config.system.build.toplevel;
      adder-ws = self.nixosConfigurations.adder-ws.config.system.build.toplevel;
    };

    nixosConfigurations = let
      system-base = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit (self.inputs) nixos-hardware;};
        modules = [
          self.inputs.disko.nixosModules.disko
          self.inputs.sops-nix.nixosModules.sops
          ./base.nix
          ./desktop-cosmic.nix
          ./user-efrem.nix
        ];
      };
    in {
      # System76 Adder WS (Laptop WorkStation)
      adder-ws = system-base.extendModules {
        modules = [
          ./adderws-config.nix
          ./home-server.nix
          {networking.hostName = "adder-ws";}
        ];
      };

      # Lenovo ThinkPad X1 Carbon 11th Gen
      thinkpad = system-base.extendModules {
        modules = [
          self.inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-11th-gen
          ./disko-laptop-ssd.nix
          ./personal-laptop.nix
          {networking.hostName = "thinkpad";}
        ];
      };
    };

    # Development Shells
    devShells.x86_64-linux = let
      pkgs = import nixpkgs {system = "x86_64-linux";};
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          sops # for managing secrets (see https://github.com/Mic92/sops-nix)
        ];
      };
    };
  };
}
