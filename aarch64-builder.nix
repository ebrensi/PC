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
  ];
  services.speechd.enable = false;
  hardware.graphics.enable = false;
  services.pipewire.enable = lib.mkForce false;

  networking = {
    # networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [22];
    };
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        AllowAgentForwarding = true;
      };
    };

    # See https://discourse.nixos.org/t/timezones-how-to-setup-on-a-laptop/33853/7
    automatic-timezoned.enable = true;
    geoclue2.geoProviderUrl = "https://api.beacondb.net/v1/geolocate";

    avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
      ipv6 = false;
      openFirewall = true;
      publish = {
        # see https://linux.die.net/man/5/avahi-daemon.conf
        enable = true;
        userServices = true;
        addresses = true;
      };
    };
  };

  # Auto optimize the Nix store
  nix.optimise = {
    automatic = true;
    dates = ["03:45"];
  };

  # Automatic garbage collection for Nix store
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # see https://search.nixos.org/packages?channel=unstable
    autossh
    mosh
    btop
    nnn
    nix-output-monitor
    fastfetch
    micro
    speedtest-cli

    pv # progress viewer for long aws uploads
    awscli2 # For building & publishing Vision Docker image
    zstd # Compression for docker image tarball
    openssl # For SHA256 checksum generation
    go # For VERSION calculation via svu tool
    gnumake # Make build tool
    bashInteractive
    uv # Python dependency management tool
    coreutils
    python3 # needed by uv for pip compile
    gcc

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

  programs = {
    starship.enable = true;
    bat.enable = true;
    git.enable = true;
    htop.enable = true;
    tmux = {
      enable = true;
      clock24 = true;
      terminal = "screen-256color";
      plugins = [
        pkgs.tmuxPlugins.cpu
        pkgs.tmuxPlugins.continuum
      ];
      extraConfig = ''
        set -g mouse on
        set -g status-right "#[fg=black,bg=color15] #{cpu_percentage} %H:%M"
        run-shell ${pkgs.tmuxPlugins.cpu}/share/tmux-plugins/cpu/cpu.tmux
      '';
    };
    # This would go in /etc/ssh/ssh_config in a traditional linux distro
    ssh.extraConfig = ''
      # Base config for all hosts
      Host *
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        ForwardAgent yes
        AddKeysToAgent yes
    '';
  };

  age.secrets.aws-credentials = {
    file = ./secrets/aws-credentials.age;
    path = "/home/efrem/.aws/credentials";
    mode = "644";
    owner = "efrem";
  };

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["efrem"];
    substituters = [
      "https://cache.nixos.org?priority=0"
      "https://guardian-ops-nix.s3.us-west-2.amazonaws.com?priority=1"
    ];
    trusted-public-keys = [
      "guardian-nix-cache:vN2kJ7sUQSbyWv4908FErdTS0VrPnMJtKypt21WzJA0="
    ];
  };
  nix.nixPath = ["nixpkgs=${pkgs.path}"];

  users.users.efrem = {
    isNormalUser = true;
    description = "Efrem Rensi";
    extraGroups = ["networkmanager" "wheel" "docker"];
    initialPassword = "p";
    openssh.authorizedKeys.keys = with (import ./secrets/public-keys.nix); [personal-ssh-key];
  };
  security.sudo.wheelNeedsPassword = false;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
