{
  options,
  config,
  lib,
  pkgs,
  #
  agenix,
  ...
}: {
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
  };

  networking = {
    useDHCP = lib.mkDefault true;
    enableIPv6 = true;
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
      wifi.backend = "iwd";
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [22];
    };
    timeServers = options.networking.timeServers.default ++ ["time.aws.com"];

    wireless.iwd = {
      enable = lib.mkForce true;
      settings = {
        Network = {
          EnableIPv6 = true;
          NameResolvingService = "systemd";
          # RoutePriorityOffset = 0;
        };
        Settings = {
          AutoConnect = true;
        };
      };
    };
  };

  # Allows fallback to other DNS servers if this LAN's DNS is slow or failing
  # Fixes problem with nix S3 cache uploads going into timeout loop
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "allow-downgrade";
      MulticastDNS = "no";
      FallbackDNS = ["1.1.1.1" "8.8.8.8"];
    };
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        AllowAgentForwarding = true;
      };
    };

    fwupd.enable = true;

    # See https://discourse.nixos.org/t/timezones-how-to-setup-on-a-laptop/33853/7
    automatic-timezoned.enable = true;
    geoclue2.geoProviderUrl = "https://api.beacondb.net/v1/geolocate";

    avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
      ipv6 = true;
      openFirewall = true;
      publish = {
        # see https://linux.die.net/man/5/avahi-daemon.conf
        enable = true;
        userServices = true;
        addresses = true;
      };
      denyInterfaces = ["virbr0" "docker0" "lo"];
    };
  };

  # Security
  security.polkit.enable = true;

  # Virtualization (useful for development/testing)
  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true;
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

  # Allow unfree packages (needed for NVIDIA drivers and some software)
  nixpkgs.config.allowUnfree = true;

  # Unless otherwise specified, this configuration is gonna be built on and for x86_64-linux
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nixpkgs.buildPlatform = lib.mkDefault "x86_64-linux";

  # System packages
  environment.systemPackages = with pkgs; [
    # see https://search.nixos.org/packages?channel=unstable

    # Admin
    autossh

    # System essentials
    wget
    curl
    net-tools

    # Archive tools
    unzip
    p7zip

    # Hardware tools
    pciutils
    usbutils
    lshw
    dmidecode

    # Development
    gcc
    gnumake
    btop
    ncdu
    tree
    nnn
    nix-output-monitor
    nix-fast-build
    nixos-anywhere
    tig
    nodePackages_latest.prettier

    # Utilities
    wl-clipboard-x11
    wl-clipboard-rs
    trash-cli
    fastfetch
    speedtest-cli
    systemctl-tui
    jq

    agenix.packages.${pkgs.stdenv.hostPlatform.system}.agenix
  ];

  # https://search.nixos.org/options?channel=unstable&query=programs
  programs = {
    mosh.enable = true;
    yazi.enable = true;
    starship.enable = true;
    bat.enable = true;
    git.enable = true;
    git.lfs.enable = true;
    lazygit.enable = true;
    wavemon.enable = true;
    usbtop.enable = true;
    htop.enable = true;
    iotop.enable = true;
    fzf.fuzzyCompletion = true;
    tmux.enable = true;
    neovim = {
      enable = true;
      vimAlias = true;
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

  # This is so symbols in Starship prompt are rendered correctly.
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
  ];

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    substituters = ["https://nix-community.cachix.org"];
    trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
    download-buffer-size = 524288000;
  };
  nix.nixPath = ["nixpkgs=${pkgs.path}"];
  system.stateVersion = "25.05";
}
