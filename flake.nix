{
  description = "NixOS configuration for Personal Machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-apple-silicon.url = "github:nix-community/nixos-apple-silicon";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: {
    nixosConfigurations = let
      system-base = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit (self.inputs) nixos-hardware;};
        modules = [
          self.inputs.disko.nixosModules.disko
          self.inputs.agenix.nixosModules.default
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

      # Apple Mac Mini M1 configured as aarch64 builder
      m1 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          self.inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
          ./machines/mac-mini-m1.nix
          ./builder.nix
          {networking.hostName = "m1";}
        ];
      };
    };

    packages.x86_64-linux = let
      pkgs = import nixpkgs {system = "x86_64-linux";};
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
      thinkpad-offline-installer-iso = mkInstaller "thinkpad";
      adder-ws-offline-installer-iso = mkInstaller "adder-ws";

      thinkpad = self.nixosConfigurations.thinkpad.config.system.build.toplevel;
      adder-ws = self.nixosConfigurations.adder-ws.config.system.build.toplevel;
      m1 = self.nixosConfigurations.m1.config.system.build.toplevel;
    };

    # Development Shells
    # Make deployment/etc scripts available with `nix develop`
    devShells.x86_64-linux = let
      pkgs = import nixpkgs {system = "x86_64-linux";};
      dev-scripts = builtins.attrValues (import ./dev-scripts.nix {inherit pkgs;});
    in {
      default = pkgs.mkShell {
        buildInputs = [self.inputs.agenix.packages.x86_64-linux.agenix] ++ dev-scripts;
        NIX_CONFIG = ''
          warn-dirty = false  # We don't need to see this warning on every build
        '';
      };
    };
  };
}
