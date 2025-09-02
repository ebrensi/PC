{
  description = "NixOS configuration for Personal Machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-facter-modules = {
      url = "github:numtide/nixos-facter-modules";
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
    };
    nixosConfigurations = {
      adder-ws = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.inputs.nixos-facter-modules.nixosModules.facter
          self.inputs.disko.nixosModules.disko
          ./disko-laptop-ssd.nix
          ./base.nix
          ./users.nix
          ./system76.nix
          ./desktop-cosmic.nix
          ./adderWS-config.nix
          ./hwconf.nix
          # ./facter-adder-ws.json
          {
            networking.hostName = "adder-ws";
            # config.facter.reportPath = ./facter-adder-ws.json;
          }
        ];
      };
    };
  };
}
