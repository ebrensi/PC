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
    networkmanager = {
      enable = true;
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [22];
    };
    timeServers = options.networking.timeServers.default ++ ["time.aws.com"];
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        AllowAgentForwarding = true;
      };
    };
    tailscale.enable = true;

    printing = {
      # see https://wiki.nixos.org/wiki/Printing
      enable = true;
      cups-pdf.enable = true;
      browsing = true;
      drivers = [
        pkgs.cups-filters
        pkgs.cups-browsed
      ];
    };

    fwupd.enable = true;

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

    # nvtopPackages.full  # Disabled while cuda builds fail

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
    firefox.enable = true;
    xwayland.enable = true;
    wavemon.enable = true;
    usbtop.enable = true; # not building
    htop.enable = true;
    iotop.enable = true;
    fzf.fuzzyCompletion = true;
    tmux.enable = true;
    neovim = {
      enable = true;
      vimAlias = true;
    };
    vscode.enable = true;
    vscode.extensions = with pkgs.vscode-extensions; [
      # For all extenstions
      # see https://search.nixos.org/packages?channel=unstable&query=vscode-extensions

      # Nix
      jnoortheen.nix-ide
      bbenoist.nix
      jeff-hykin.better-nix-syntax

      # Python
      ms-toolsai.jupyter
      ms-python.python
      ms-python.vscode-pylance
      ms-python.pylint
      # ms-python.flake8
      ms-python.mypy-type-checker
      ms-python.isort
      ms-python.debugpy
      ms-python.black-formatter
      charliermarsh.ruff

      # Go
      golang.go

      tamasfe.even-better-toml
    ];

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

  hardware.bluetooth = {
    # https://nixos.wiki/wiki/Bluetooth
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Shows battery charge of connected devices on supported Bluetooth adapters.
        Experimental = true;
        # When enabled other devices can connect faster to us, however
        # the tradeoff is increased power consumption.
        FastConnectable = true;
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on.
        AutoEnable = true;
      };
    };
  };

  # Enable sound with pipewire (not Pulse Audio).
  # https://wiki.nixos.org/wiki/PipeWire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    substituters = ["https://nix-community.cachix.org?priority=200"];
    trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
    download-buffer-size = 524288000;
  };
  nix.nixPath = ["nixpkgs=${pkgs.path}"];
  system.stateVersion = "25.05";
}
