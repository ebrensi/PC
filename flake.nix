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
      '';
      make-install-target = pkgs.writeShellScriptBin "make-install-target" ''
        dest=$1
        if [ -z "$dest" ]; then
          echo "Usage: make-install-target <destination-file>"
          exit 1
        fi
        echo "Building installation ISO image..."
        isoPath=$(${nom} build .#nixosConfigurations.install-target.config.system.build.isoImage --print-out-paths --no-link)
        isoFile=$(ls $isoPath/*.iso)
        echo "Copying $isoFile to $dest..."
        sudo dd if=$isoFile of=$dest bs=4M status=progress oflag=sync
        sudo eject $dest || true
      '';
    };
    nixosConfigurations = rec {
      install-target = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          {
            services.openssh.enable = true;
            # Paste your SSH public key here to enable SSH access to the installation target.
            users.users.root.openssh.authorizedKeys.keys = ["my-ssh-pubkey"];
            networking.hostName = "install-target";
            services.avahi = {
              enable = true;
              openFirewall = true;
              publish = {
                enable = true;
                userServices = true;
                addresses = true;
              };
            };
            nix.settings = {
              experimental-features = ["nix-command" "flakes"];
              trusted-users = ["@wheel"];
            };
            system.stateVersion = "25.05";
          }
        ];
      };
      # System76 Adder WS (Laptop WorkStation)
      adder-ws = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit (self.inputs) nixos-hardware;};
        modules = [
          self.inputs.disko.nixosModules.disko
          ./base.nix
          ./desktop-cosmic.nix
          ./adderws-config.nix
          ./users.nix
          {
            networking.hostName = "adder-ws";
            # use older version of tailscale that builds, since the latest doesn't
            services.tailscale.package = let pkgs-stable = import nixpkgs-stable {system = "x86_64-linux";}; in pkgs-stable.tailscale;
          }
        ];
      };
      # Lenovo ThinkPad X1 Carbon 11th Gen
      thinkpad = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.inputs.disko.nixosModules.disko
          self.inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-11th-gen
          # ./thinkpad.hardware.nix
          ./disko-laptop-ssd.nix
          ./base.nix
          ./desktop-cosmic.nix
          ./users.nix
          {
            networking.hostName = "thinkpad";
          }
        ];
      };
    };
  };
}
