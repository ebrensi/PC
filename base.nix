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

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
    };

    optimise = {
      automatic = true;
      dates = ["03:45"];
    };

    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # See https://discourse.nixos.org/t/timezones-how-to-setup-on-a-laptop/33853/7
  # services.tzupdate.enable = true;
  services.automatic-timezoned.enable = true;
  services.geoclue2.geoProviderUrl = "https://api.beacondb.net/v1/geolocate";

  # Allow unfree packages (needed for NVIDIA drivers and some software)
  nixpkgs.config.allowUnfree = true;

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

    # Development
    gcc
    gnumake
    htop
    iotop
    btop
    ncdu
    tree
    fzf
    tmux
    nnn

    # Media
    firefox

    # Networking
    networkmanagerapplet
  ];

  system.stateVersion = "25.05";
}
