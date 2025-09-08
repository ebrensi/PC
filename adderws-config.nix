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

  # Display and Desktop Environment
  services = {
    openssh.enable = true;
    printing.enable = true;
    fwupd.enable = true;
  };

  # Security
  security.polkit.enable = true;

  # Virtualization (useful for development/testing)
  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true;
  };

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
  ];

  hardware.enableRedistributableFirmware = true;
  hardware.firmware = [pkgs.linux-firmware];
  hardware.nvidia = {
    open = true;
    nvidiaSettings = true;
    prime = {
      nvidiaBusId = "PCI:1:0:0";
      intelBusId = "PCI:0:2:0";
    };
  };
  hardware.nvidia-container-toolkit.enable = true;
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
  services.power-profiles-daemon.enable = false;
}
