{
  config,
  lib,
  pkgs,
  ...
}: {
  # Networking
  networking = {
    networkmanager.enable = true;

    # Enable firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [22]; # SSH
    };
  };

  hardware = {
    # Bluetooth
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # Display and Desktop Environment
  services = {
    # Essential services
    openssh.enable = true;
    printing.enable = true;

    # Power management
    # thermald.enable = true;

    # Firmware updates
    fwupd.enable = true;
  };

  # Security
  security.polkit.enable = true;

  # Virtualization (useful for development/testing)
  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true;
  };

  hardware.enableRedistributableFirmware = true;
  hardware.firmware = [pkgs.linux-firmware];
  services.tailscale.enable = true;

  programs = {
    git.enable = true;
    git.lfs.enable = true;
    firefox.enable = true;
    xwayland.enable = true;
    starship.enable = true;
    command-not-found.enable = true;
    yazi.enable = true;
    wavemon.enable = true;
    vscode.enable = true;
    usbtop.enable = true;
    tmux.enable = true;
    ssh = {
      startAgent = lib.mkForce false;
    };
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard-x11
  ];
}
