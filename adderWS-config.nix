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
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = false; # Use proprietary driver
      nvidiaSettings = true;
      # package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

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

    # Flatpak support for COSMIC Store
    flatpak.enable = true;
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
      extraConfig = ''
        Host *.local
          StrictHostKeyChecking no
          UserKnownHostsFile /dev/null
          ForwardAgent yes

          # Reuse local ssh connections
          ControlPath /tmp/ssh/%r@%h:%p
          ControlMaster auto
          ControlPersist 20
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard-x11
  ];
}
