{
  description = "NixOS configuration for Personal Machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-apple-silicon.url = "github:nix-community/nixos-apple-silicon";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code-nix.url = "github:sadjow/claude-code-nix";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: {
    nixosConfigurations = let
      pkgs-stable = import self.inputs.nixpkgs-stable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      system-base = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit (self.inputs) agenix;
          inherit pkgs-stable;
        };
        modules = [
          self.inputs.disko.nixosModules.disko
          self.inputs.agenix.nixosModules.default
          {nixpkgs.overlays = [self.inputs.claude-code-nix.overlays.default];}
          ./patches/module.nix
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
      m1 = system-base.extendModules {
        modules = [
          self.inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
          self.inputs.agenix.nixosModules.default
          ./machines/mac-mini-m1.nix
          ./aarch64-builder.nix
          {networking.hostName = "m1";}
        ];
      };

      # Orange Pi 5 Plus (RK3588) as a Kodi TV box.
      #  Built from base.nix alone rather than system-base: user-efrem.nix brings
      #  dev repos and agenix credentials that have no business on a TV.
      tv = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit (self.inputs) agenix;
          inherit pkgs-stable;
        };
        modules = [
          self.inputs.disko.nixosModules.disko
          ./patches/module.nix
          ./base.nix
          ./disko-laptop-ssd.nix
          ./machines/orangepi-5-plus.nix
          ./tv.nix
          {networking.hostName = "tv";}
        ];
      };
    };

    packages.x86_64-linux = let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true; # rkboot (Rockchip's USB loader blobs)
      };
      platform = pkgs.stdenv.hostPlatform.system;
      keys = import ./secrets/public-keys.nix;
      dev-scripts-attrs = import ./dev-scripts.nix {inherit pkgs;};
      mkNetworkInstaller = hostPlatform:
        nixpkgs.lib.nixosSystem {
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"
            self.inputs.agenix.nixosModules.default
            ./network-installer.nix
            {
              nixpkgs.hostPlatform = hostPlatform;
              networking.wireless.networks.CiscoKid.pskRaw = "8c1b86a16eecd3996e724f7e21ff1818b03c8c463457fc9a3901c5ef7bc14d55";
              users.users.root.openssh.authorizedKeys.keys = [keys.personal-ssh-key];
            }
          ];
        };
      installer-base = mkNetworkInstaller "x86_64-linux";
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
        tv = self.nixosConfigurations.tv.config.system.build.toplevel;

        network-installer-iso = installer-base.config.system.build.isoImage;
        # Boots on the Orange Pi 5 Plus once tv-flash-spi has put U-Boot on it.
        #  Use a black USB 2.0 port: U-Boot does not boot from the blue USB 3.0 ones.
        network-installer-aarch64-iso = (mkNetworkInstaller "aarch64-linux").config.system.build.isoImage;

        # Write mainline U-Boot to the Orange Pi 5 Plus SPI flash over USB.
        #  The board must be in MaskROM mode: unplug power, hold the MaskROM
        #  button, plug in power, release; then connect its USB-C data port
        #  (not the power port) to this machine. `lsusb` shows 2207:350b.
        tv-flash-spi = pkgs.writeShellApplication {
          name = "tv-flash-spi";
          text = let
            uboot = self.nixosConfigurations.tv.pkgs.ubootOrangePi5Plus;
            rkdeveloptool = pkgs.lib.getExe pkgs.rkdeveloptool;
          in ''
            # Rockchip's USB loader: trains DRAM and runs the flashing stub
            loader=$(find ${pkgs.rkboot}/bin -name 'rk3588_loader_v*.bin' | sort -V | tail -1)
            image=${uboot}/u-boot-rockchip-spi.bin

            sudo ${rkdeveloptool} ld
            sudo ${rkdeveloptool} db "$loader"
            sudo ${rkdeveloptool} cs 9 # 9 = SPI NOR
            sudo ${rkdeveloptool} wl 0 "$image"
            sudo ${rkdeveloptool} rd
            echo "U-Boot written to SPI flash; the board is rebooting."
          '';
        };

        all-systems = pkgs.linkFarm "all-systems" (
          map (name: {
            name = name;
            path = self.nixosConfigurations.${name}.config.system.build.toplevel;
          })
          ["thinkpad" "adder-ws" "m1" "tv"]
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
        '';
      };
    };
  };
}
