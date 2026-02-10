{
  description = "NixOS configuration for Personal Machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
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
      pkgs-stable = import self.inputs.nixpkgs-stable {system = "x86_64-linux";};
      system-base = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit (self.inputs) nixos-hardware agenix;
          inherit pkgs-stable;
        };
        modules = [
          self.inputs.disko.nixosModules.disko
          self.inputs.agenix.nixosModules.default
          ./base.nix
          ./user-efrem.nix
        ];
      };
      gui-base = system-base.extendModules {
        modules = [
          ./desktop-cosmic.nix
          ./graphical.nix
          ./disko-laptop-ssd.nix
        ];
      };
    in {
      # System76 Adder WS (Laptop WorkStation)
      adder-ws = gui-base.extendModules {
        modules = [
          ./machines/system76-adderws.nix
          ./home-server.nix
          {networking.hostName = "adder-ws";}
        ];
      };

      # Lenovo ThinkPad X1 Carbon 11th Gen
      thinkpad = gui-base.extendModules {
        modules = [
          ./machines/thinkpad.nix
          ./personal-laptop.nix
          {networking.hostName = "thinkpad";}
        ];
      };

      # Apple Mac Mini M1 configured as aarch64 builder
      m1 = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit (self.inputs) agenix;
        };
        modules = [
          self.inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
          self.inputs.agenix.nixosModules.default
          ./machines/mac-mini-m1.nix
          ./aarch64-builder.nix
          ./user-efrem.nix
          {
            networking.hostName = "m1";
            services.openssh.enable = true;
            nixpkgs.config.allowUnfree = true;
            nix.settings = {
              experimental-features = ["nix-command" "flakes"];
              download-buffer-size = 524288000;
            };
            system.stateVersion = "25.05";
          }
        ];
      };
    };

    packages.x86_64-linux = let
      pkgs = import nixpkgs {system = "x86_64-linux";};
      platform = pkgs.stdenv.hostPlatform.system;
      keys = import ./secrets/public-keys.nix;
      dev-scripts-attrs = import ./dev-scripts.nix {inherit pkgs;};

      installer-base = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"
          self.inputs.agenix.nixosModules.default
          ./network-installer.nix
          {
            networking.wireless.networks.CiscoKid.pskRaw = "8c1b86a16eecd3996e724f7e21ff1818b03c8c463457fc9a3901c5ef7bc14d55";
            users.users.root.openssh.authorizedKeys.keys = [keys.personal-ssh-key];
          }
        ];
      };
      mkInstaller = hostname:
        (installer-base.extendModules {
          modules = [./offline-installer.nix];
          specialArgs = {systemToInstall = self.nixosConfigurations.${hostname};};
        }).config.system.build.isoImage;
    in
      rec {
        thinkpad-offline-installer-iso = mkInstaller "thinkpad";
        adder-ws-offline-installer-iso = mkInstaller "adder-ws";

        thinkpad = self.nixosConfigurations.thinkpad.config.system.build.toplevel;
        adder-ws = self.nixosConfigurations.adder-ws.config.system.build.toplevel;
        m1 = self.nixosConfigurations.m1.config.system.build.toplevel;

        network-installer-iso = installer-base.config.system.build.isoImage;

        all-systems = pkgs.linkFarm "all-systems" (
          map (name: {
            name = name;
            path = self.nixosConfigurations.${name}.config.system.build.toplevel;
          })
          ["thinkpad" "adder-ws" "m1"]
        );
        test = pkgs.writeShellScriptBin "test" ''
          source ${dev-scripts-attrs.nix-config}
          exec ${pkgs.lib.getExe pkgs.nix-fast-build} --flake .#packages.${platform}.all-systems --skip-cached
        '';
      }
      // dev-scripts-attrs;

    # Development Shells
    # Make deployment/etc scripts available with `nix develop`
    devShells.x86_64-linux = let
      pkgs = import nixpkgs {system = "x86_64-linux";};
      dev-scripts-list = builtins.attrValues (import ./dev-scripts.nix {inherit pkgs;});
    in {
      default = pkgs.mkShell {
        buildInputs = [self.inputs.agenix.packages.x86_64-linux.agenix] ++ dev-scripts-list;
        NIX_CONFIG = ''
          warn-dirty = false  # We don't need to see this warning on every build
          always-allow-substitutes = true
        '';
      };
    };
  };
}
