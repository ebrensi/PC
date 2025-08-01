# NixOS Configuration for System76 Adder WS with COSMIC Desktop
# This configuration provides a complete setup for your System76 Adder laptop
# with the COSMIC desktop environment and proper hardware support
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan
    # ./hardware-configuration.nix

    # System76 hardware support - use nixos-hardware for better compatibility
    # You can add this via: sudo nix-channel --add https://github.com/NixOS/nixos-hardware/archive/master.tar.gz nixos-hardware
    # Then uncomment the line below:
    # <nixos-hardware/system76>
  ];

  # Boot Configuration
  boot = {
    # Use the systemd-boot EFI boot loader
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # Latest kernel for best hardware support
    kernelPackages = pkgs.linuxPackages_latest;

    # System76 specific kernel parameters
    kernelParams = [
      "ec_sys.write_support=1" # Required for System76 hardware support
    ];

    # Enable firmware updates
    kernelModules = ["system76_acpi"];
  };

  # Networking
  networking = {
    hostName = "adder-nixos"; # Change this to your preferred hostname
    networkmanager.enable = true;

    # Enable firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [22]; # SSH
    };
  };

  # Time and Locale
  time.timeZone = "America/Denver"; # Change to your timezone
  i18n.defaultLocale = "en_US.UTF-8";

  # Nix Configuration
  nix = {
    settings = {
      # Enable flakes and new nix command
      experimental-features = ["nix-command" "flakes"];

      # COSMIC binary cache for faster builds
      substituters = [
        "https://cosmic.cachix.org/"
      ];
      trusted-public-keys = [
        "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      ];
    };

    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # System76 Hardware Support
  hardware = {
    # Enable System76 support
    system76 = {
      enableAll = true;
      # kernel-modules.enable = true;
      # power-daemon.enable = true;
      # firmware-daemon.enable = true;
    };

    # Graphics support (important for System76 laptops with discrete GPUs)
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    # NVIDIA support (if your Adder has NVIDIA GPU)
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = false; # Use proprietary driver
      nvidiaSettings = true;
      # Use latest driver
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    # Bluetooth
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    # Audio
    pulseaudio.enable = false; # We'll use PipeWire instead
  };

  # Audio with PipeWire (better for modern systems)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Display and Desktop Environment
  services = {
    # X11 and Wayland support
    # xserver = {
    #   enable = true;
    #   # Configure keymap
    #   xkb = {
    #     layout = "us";
    #     variant = "";
    #   };
    # };

    # COSMIC Desktop Environment
    # desktopManager.cosmic.enable = true;
    # displayManager.cosmic-greeter.enable = true;

    # Essential services
    openssh.enable = true;
    printing.enable = true;

    # Power management
    thermald.enable = true;
    power-profiles-daemon.enable = true;

    # Firmware updates
    fwupd.enable = true;

    # Flatpak support for COSMIC Store
    flatpak.enable = true;
  };

  # User Configuration
  users.users.efrem = {
    isNormalUser = true;
    description = "Efrem Rensi";
    extraGroups = ["networkmanager" "wheel" "audio" "video"];
    packages = with pkgs; [
      # Development tools (since you mentioned system administration)
      git
      vim
      neovim
      micro
      vscode
      docker

      # System monitoring and management
      htop
      iotop
      btop
      ncdu
      tree
      fzf
      tmux
      nnn

      # COSMIC applications
      # cosmic-files
      # cosmic-edit
      # cosmic-term
      # cosmic-settings

      # Additional useful applications
      firefox
      google-chrome
      # libreoffice

      # Media
      vlc

      # Archive tools
      unzip
      p7zip
    ];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    # System essentials
    wget
    curl
    git
    vim

    # Hardware tools
    pciutils
    usbutils
    lshw
    dmidecode

    # System76 tools
    system76-firmware
    system76-power

    # Development
    gcc
    gnumake

    # Networking
    networkmanagerapplet

    # File systems
    ntfs3g
    exfat
  ];

  # Security
  security = {
    sudo.wheelNeedsPassword = true;
    polkit.enable = true;
  };

  # Virtualization (useful for development/testing)
  virtualisation = {
    docker.enable = true;
    # Uncomment if you want libvirt/KVM
    # libvirtd.enable = true;
  };

  # Allow unfree packages (needed for NVIDIA drivers and some software)
  nixpkgs.config.allowUnfree = true;

  # System state version - don't change after initial install
  system.stateVersion = "24.11"; # Change to match your NixOS version
}
