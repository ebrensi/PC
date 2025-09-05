{
  description = "NixOS configuration for Personal Machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: {
    packages.x86_64-linux = let
      pkgs = import nixpkgs {system = "x86_64-linux";};
      nixos-anywhere = "${pkgs.nixos-anywhere}/bin/nixos-anywhere";
    in {
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
    };
    nixosConfigurations = {
      adder-ws = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.inputs.disko.nixosModules.disko
          ./disko-laptop-ssd.nix
          ./base.nix
          ./users.nix
          ./system76.nix
          ./desktop-cosmic.nix
          ./nvidia.nix
          ./adderWS-config.nix
          ./adderws.hardware.nix
          {
            networking.hostName = "adder-ws";
          }
        ];
      };
    };
  };
}
