# Generic builder profile
#  This is a machine used for building Nix packages and systems remotely.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/profiles/headless.nix"
    ./wireguard-peer.nix
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs.buildPlatform = "aarch64-linux";
  hardware.graphics.enable = false;

  users.users.builder = {
    isSystemUser = true; # No password, UID < 1000, no home dir
    group = "builder";
    shell = pkgs.bash; # SSH needs a shell to run `nix-store --serve`
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFMlODk3W6OUoCdDCSPOPasBO/ldWEPKQaUC9wTedSX0 guardian@AP1"
    ];
  };
  users.groups.builder = {};
  nix.settings.trusted-users = ["builder"]; # Allows builder to interact with nix daemon

  networking = {
    # networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [22];
    };
  };

  services = {
    speechd.enable = false;
    pipewire.enable = lib.mkForce false;
  };

  environment.systemPackages = with pkgs; [
    zstd # Compression for docker image tarball
    openssl # For SHA256 checksum generation
    go # For VERSION calculation via svu tool
    gnumake # Make build tool
    bashInteractive
    uv # Python dependency management tool
    coreutils
    python3 # needed by uv for pip compile
    gcc

    # Build to alternate nix store on USB NVMe
    # Usage: nix-build-ext .#package
    (pkgs.writeShellScriptBin "nix-build-ext" ''
      set -euo pipefail
      ALT_STORE="/mnt/nix-alt"
      if ! mountpoint -q "$ALT_STORE"; then
        echo "Error: $ALT_STORE is not mounted. Is the USB drive connected?" >&2
        exit 1
      fi
      echo "Building to external store: $ALT_STORE" >&2
      nix build --store "$ALT_STORE" "$@"
    '')

    # Build the m1 system config to the alt store, copy to primary store, and switch.
    # Usage: nixos-rebuild-ext [flake-path]   (defaults to current directory)
    (pkgs.writeShellScriptBin "nixos-rebuild-ext" ''
      set -euo pipefail
      FLAKE="''${1:-.}"
      ALT_STORE="/mnt/nix-alt"
      nom="${pkgs.nix-output-monitor}/bin/nom"

      if ! mountpoint -q "$ALT_STORE"; then
        echo "Error: $ALT_STORE is not mounted. Is the USB drive connected?" >&2
        exit 1
      fi

      echo "==> Building m1 configuration to $ALT_STORE..." >&2
      altPath=$(
        $nom build "$FLAKE#nixosConfigurations.m1.config.system.build.toplevel" \
          --store "$ALT_STORE" \
          --no-link \
          --print-out-paths
      )
      canonicalPath="/nix/store/$(basename "$altPath")"
      echo "==> Built: $canonicalPath" >&2

      echo "==> Copying closure to primary store..." >&2
      nix copy --from "local?root=$ALT_STORE" --no-check-sigs "$canonicalPath"

      echo "==> Activating..." >&2
      sudo nix-env -p /nix/var/nix/profiles/system --set "$canonicalPath"
      sudo "$canonicalPath/bin/switch-to-configuration" switch
      echo "==> Done." >&2
    '')

    # Docker cleanup script - removes old guardian/vision images, keeps build cache
    (pkgs.writeShellScriptBin "docker-cleanup-vision" ''
      #!/usr/bin/env bash
      set -euo pipefail

      echo "=== Docker Cleanup: Removing old guardian/vision images ==="
      echo "Note: Build cache will be preserved for faster rebuilds"
      echo ""

      # Remove dangling (untagged) images
      echo "Step 1: Removing dangling images..."
      docker image prune -f
      echo ""

      # Remove old guardian/vision images, keeping only latest 2 versions
      echo "Step 2: Cleaning old guardian/vision images (keeping latest 2)..."
      # List all guardian/vision images sorted by creation date (oldest first)
      # Skip the first line (header) and the last 2 lines (newest images)
      docker images guardian/vision --format "{{.ID}} {{.Repository}}:{{.Tag}} {{.CreatedAt}}" | \
        sort -k3 | \
        head -n -2 | \
        awk '{print $1}' | \
        while read -r image_id; do
          if [ -n "$image_id" ]; then
            echo "  Removing image: $image_id"
            docker rmi "$image_id" 2>/dev/null || echo "  (already removed or in use)"
          fi
        done
      echo ""

      echo "Step 3: Current status:"
      docker system df
      echo ""
      echo "✓ Cleanup complete! Build cache preserved."
    '')
  ];

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  age.secrets.wg-m1.file = ./secrets/wg-m1.age;
  # public key: aZEHKJGXFvCe8eOmMCdhD+okIuOkQUULZzKJZ+MWDRU=
  wireguard-peer = let
    prefix = config.wireguard-peer.prefix;
  in {
    enable = true;
    listenPort = 51820;
    ips = ["${prefix}4/128"];
    privateKeyFile = config.age.secrets.wg-m1.path;
    peers = [
      {
        name = "adderws";
        publicKey = "srov/ElxjM0BPfQHhCFN2sb3UEkwIhFQGSS55P/HIEA=";
        allowedIPs = ["${prefix}1/128"];
        endpoint = "73.15.57.26:55555";
      }
      {
        name = "thinkpad";
        publicKey = "wa7WjWFn1SsOLQwOw3EMC1JY29WjU7vLvNlxRtySoTg=";
        allowedIPs = ["${prefix}2/128"];
      }
      {
        name = "AP1";
        publicKey = "tpiOxpH1iI/Y5MU7yyVdfFMQBblM+HWPObMlFPF7tlw=";
        allowedIPs = ["fd42::9d0c:6962:4451:2cff/128"];
      }
    ];
  };

  programs = {
    mosh.enable = true;
    starship.enable = true;
    bat.enable = true;
    git.enable = true;
    htop.enable = true;
  };
  boot.loader.systemd-boot.configurationLimit = 5;
}
