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
    nixos-apple-silicon.url = "github:tpwrules/nixos-apple-silicon";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
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
          ./disko-laptop-ssd.nix
        ];
      };
    in {
      # System76 Adder WS (Laptop WorkStation)
      adder-ws = system-base.extendModules {
        modules = [
          ./machines/system76-adderws.nix
          ./home-server.nix
          {networking.hostName = "adder-ws";}
        ];
      };

      # Lenovo ThinkPad X1 Carbon 11th Gen
      thinkpad = system-base.extendModules {
        modules = [
          self.inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-11th-gen
          ./personal-laptop.nix
          {networking.hostName = "thinkpad";}
        ];
      };

      mac-mini = system-base.extendModules {
        system = "aarch64-linux";
        specialArgs = {inherit (self.inputs) nixos-apple-silicon;};
        modules = [
          ./machines/m1-mac-mini.nix
          {networking.hostName = "mac-mini";}
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
          nix-fast-build
        ];
        NIX_CONFIG = ''
          warn-dirty = false  # We don't need to see this warning on every build
        '';
      };
    };
  };
}
