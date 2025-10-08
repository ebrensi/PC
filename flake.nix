{
  description = "NixOS configuration for Personal Machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-apple-silicon.url = "github:nix-community/nixos-apple-silicon";
    sops-nix.url = "github:Mic92/sops-nix"; #TODO: either get rid of this or make it work
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    nixos-hardware,
    ...
  }: {
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
      sshOpts = "-A -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectionAttempts=5 -o ConnectTimeout=3";
    in rec {
      install-direct = pkgs.writeShellScriptBin "install-direct" ''
        # Usage: install-direct <flakePath> <host:port>

        flakePath=$1
        hostAndPort=$2
        IFS=':' read -r host port <<< "$hostAndPort"
        [ -n "$port" ] && PORT_OPT="-p $port"

        systemPath=$(${nom} build $flakePath.config.system.build.toplevel --no-link --print-out-paths) || {
          echo "Failed to build system closure"
          exit 1
        }
        diskoScript=$(nix build $flakePath.config.system.build.diskoScript --no-link --print-out-paths) || {
          echo "Failed to build disko script"
          exit 1
        }
        echo "Installing $flakePath on $hostAndPort"
        ${pkgs.nixos-anywhere}/bin/nixos-anywhere  \
            --no-substitute-on-destination \
            --build-on local \
            --store-paths $diskoScript $systemPath \
            --target-host $host $PORT_OPT
      '';

      copy-to = pkgs.writeShellScriptBin "copy-to" ''
        # Copy a nix store path directly to a remote machine via ssh
        # usage: copy-to <host:port> <path>

        targetHost=$1
        storePath=$2
        echo "Copying $storePath closure to $host..." >&2
        sshOpts="${sshOpts}"

        NIX_SSHOPTS="$sshOpts" nix copy  \
          --no-check-sigs \
          --no-update-lock-file \
          --to ssh-ng://"$targetHost"\
          "$storePath"

        # NIX_SSHOPTS="$sshOpts" nix-copy-closure -s --gzip --to "$targetHost" "$storePath"
        echo "Done Copying."
      '';
      deploy-direct = pkgs.writeShellScriptBin "deploy-direct" ''
        # Build toplevel of an arbitrary flake path locally, copy the closure it directly to a remote machine,
        #  and activate it there. Use this script to update the NixOS system already running on a remote machine,
        #  without using the remote cache.
        # Usage: deploy-direct <flakePath> <host:port>

        flakePath=$1
        targetHost=$2
        systemPath=$(${pkgs.nix-output-monitor}/bin/nom $flakePath.config.system.build.toplevel) || {
          echo "Failed to build system closure"
          exit 1
        }
        ${copy-to}/bin/* $targetHost $systemPath || {
          echo "Failed to copy system closure to remote machine"
          exit 1
        }
        ssh $sshOpts $targetHost "sudo nix-env -p /nix/var/nix/profiles/system --set $systemPath && sudo $systemPath/bin/switch-to-configuration switch" || {
          echo "Failed to activate new configuration on remote machine"
          exit 1
        }
      '';
      apply = pkgs.writeShellScriptBin "apply" ''
        # Apply a system configuration (toplelevel) path to the current system.
        # This is like `nixos-rebuild switch` but for an arbitrary path to a
        #  nixosSystem toplevel.

        storePath=$(realpath $1)
        sudo nix-env -p /nix/var/nix/profiles/system --set $storePath
        sudo $storePath/bin/switch-to-configuration switch
      '';

      thinkpad-offline-installer-iso = mkInstaller "thinkpad";
      adder-ws-offline-installer-iso = mkInstaller "adder-ws";

      thinkpad = self.nixosConfigurations.thinkpad.config.system.build.toplevel;
      adder-ws = self.nixosConfigurations.adder-ws.config.system.build.toplevel;
      m1 = self.nixosConfigurations.m1.config.system.build.toplevel;
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
