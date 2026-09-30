# Applies every entry in patches/default.nix as an overlay, and warns on
# rebuild when an entry hasn't been re-checked in over a month of nixpkgs.
{
  config,
  lib,
  ...
}: let
  registry = import ./.;
  maxAgeDays = 30;

  # Rough day count from YYYYMMDD; only used for a staleness threshold.
  days = ymd: let
    n = lib.toInt ymd;
  in
    n / 10000 * 365 + (lib.mod (n / 100) 100) * 31 + lib.mod n 100;

  # nixos.version looks like 26.11.20260929.b4fd65b
  nixpkgsDate = builtins.match "[0-9]+\\.[0-9]+\\.([0-9]{8})\\..*" config.system.nixos.version;

  stale = lib.filterAttrs (_: e:
    nixpkgsDate != null
    && days (lib.head nixpkgsDate) - days (lib.replaceStrings ["-"] [""] e.checked) > maxAgeDays)
  registry;
in {
  nixpkgs.overlays = [
    (_: prev: lib.mapAttrs (name: e: prev.${name}.overrideAttrs (e.override prev)) registry)
  ];

  warnings = lib.mapAttrsToList (name: e: "patches/default.nix: '${name}' was last checked ${e.checked}, over ${toString maxAgeDays} days behind this nixpkgs. Run `check-patches`, then drop it or bump `checked`.") stale;
}
