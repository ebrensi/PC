{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

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

  # Security
  security = {
    sudo.wheelNeedsPassword = true;
    polkit.enable = true;
  };

  # Virtualization (useful for development/testing)
  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true;
  };

  programs.ssh = {
    startAgent = true;
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
}
