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
    # The external store is configured as a substituter, so results are
    # automatically available to the local store without explicit copying
    (pkgs.writeShellScriptBin "nix-build-ext" ''
      #!/usr/bin/env bash
      set -euo pipefail

      ALT_STORE="/mnt/nix-alt"

      if ! mountpoint -q "$ALT_STORE"; then
        echo "Error: $ALT_STORE is not mounted. Is the USB drive connected?"
        exit 1
      fi

      echo "Building to external store: $ALT_STORE"
      nix build --store "$ALT_STORE" "$@"
      echo "Done. Result available via substituter."
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
    ];
  };

  programs = {
    mosh.enable = true;
    starship.enable = true;
    bat.enable = true;
    git.enable = true;
    htop.enable = true;
  };
}
