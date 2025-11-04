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
        specialArgs = {inherit (self.inputs) nixos-hardware agenix;};
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
          ./modules/gpu-passthrough.nix
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
          ({
            pkgs,
            lib,
            ...
          }: {
            networking.hostName = "thinkpad";
            services.fprintd.enable = true;
            # security.pam.services.cosmic-greeter.text = lib.mkForce ''
            #   auth sufficient ${pkgs.fprintd}/lib/security/pam_fprintd.so max-tries=3 timeout=30
            #   auth sufficient ${pkgs.linux-pam}/lib/security/pam_unix.so likeauth try_first_pass
            # '';
          })
        ];
      };
      # Apple Mac Mini M1 configured as aarch64 builder
      # TODO: maybe have this set up as a nix-darwin system
      #  so that we can still use it as a mac desktop
      m1 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          self.inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
          self.inputs.agenix.nixosModules.default
          ./machines/mac-mini-m1.nix
          ./aarch64-builder.nix
          {networking.hostName = "m1";}
        ];
      };

      vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          ({
            pkgs,
            config,
            ...
          }: {
            system.stateVersion = "25.11";
            networking.hostName = "test-vm";
            hardware.graphics.enable = true;

            # Enable NVIDIA drivers in the VM
            services.xserver.videoDrivers = ["nvidia"];
            hardware.nvidia = {
              package = config.boot.kernelPackages.nvidiaPackages.stable;
              modesetting.enable = true;
              open = false; # Use proprietary driver for better compatibility
            };

            # Blacklist nouveau to prevent conflicts with NVIDIA driver
            boot.blacklistedKernelModules = ["nouveau"];

            # Ensure NVIDIA kernel modules are loaded
            boot.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];

            # Add nvidia-smi and other NVIDIA tools to the system
            environment.systemPackages = with pkgs; [
              pciutils
              glxinfo
            ];

            users.users.efrem = {
              isNormalUser = true;
              extraGroups = ["wheel" "networkmanager" "video" "libvirtd"];
              password = "p";
            };
            services.getty.autologinUser = "efrem";

            # Enable SSH for easy access
            services.openssh = {
              enable = true;
              settings.PermitRootLogin = "yes";
            };

            virtualisation = {
              useEFIBoot = true;
              memorySize = 8192;
              cores = 4;

              # Pass through the NVIDIA GPU and audio controller
              # and configure network with SSH port forwarding
              qemu.options = [
                "-device vfio-pci,host=01:00.0,multifunction=on"
                "-device vfio-pci,host=01:00.1"
                "-netdev user,id=net0,hostfwd=tcp::2222-:22"
                "-device virtio-net-pci,netdev=net0"
              ];

              # Disable default networking since we're configuring it manually
              qemu.networkingOptions = [];
            };
          })
        ];
      };
    };

    packages.x86_64-linux = let
      pkgs = import nixpkgs {system = "x86_64-linux";};
      dev-scripts-attrs = import ./dev-scripts.nix {inherit pkgs;};
      installer-base = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = ["${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"];
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

        network-installer-iso =
          (installer-base.extendModules
            {
              modules = [
                self.inputs.agenix.nixosModules.default
                ./network-installer.nix
                {
                  networking.wireless.networks.CiscoKid.pskRaw = "8c1b86a16eecd3996e724f7e21ff1818b03c8c463457fc9a3901c5ef7bc14d55";
                  users.users.root.openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII//cI1RPUk4caXbGHdMJpQB7VuydedUCP/Kt9mALxVY efrem-angelProtection"];
                }
              ];
            }).config.system.build.isoImage;
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
