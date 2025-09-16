{
  config,
  lib,
  pkgs,
  ...
}: {
  boot = {
    # Use the systemd-boot EFI boot loader
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # Latest kernel for best hardware support
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # Networking
  networking = {
    networkmanager.enable = true;

    # Enable firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [22]; # SSH
    };
  };

  # Display and Desktop Environment
  services = {
    openssh = {
      enable = true;
      AllowAgentForwarding = true;
    };
    tailscale.enable = true;
    printing.enable = true;
    printing.cups-pdf.enable = true;
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
    nixos-anywhere
    tig
    nodePackages_latest.prettier

    # Networking
    networkmanagerapplet

    # Utilities
    wl-clipboard-x11
    wl-clipboard-rs
    trash-cli
    fastfetch
    speedtest-cli
    systemctl-tui
    jq

    go
  ];

  # https://search.nixos.org/options?channel=unstable&query=programs
  programs = {
    yazi.enable = true;
    starship.enable = true;
    bat.enable = true;
    git.enable = true;
    git.lfs.enable = true;
    lazygit.enable = true;
    firefox.enable = true;
    xwayland.enable = true;
    wavemon.enable = true;
    usbtop.enable = true;
    htop.enable = true;
    iotop.enable = true;
    fzf.fuzzyCompletion = true;
    tmux = {
      enable = true;
      clock24 = true;
      terminal = "screen-256color";
      plugins = [
        pkgs.tmuxPlugins.cpu
      ];
      extraConfig = ''
        set -g mouse on
        set -g status-right "#[fg=black,bg=color15] #{cpu_percentage} %H:%M"
        run-shell ${pkgs.tmuxPlugins.cpu}/share/tmux-plugins/cpu/cpu.tmux
      '';
    };
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
    ];
  };

  # This is so symbols in Starship prompt are rendered correctly.
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
  ];

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["@wheel"];
  };
  nix.nixPath = ["nixpkgs=${pkgs.path}"];
  system.stateVersion = "25.05";
}
