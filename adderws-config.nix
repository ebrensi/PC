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

  services.tailscale.enable = true;

  programs = {
    git.enable = true;
    git.lfs.enable = true;
    firefox.enable = true;
    xwayland.enable = true;
    command-not-found.enable = true;
    wavemon.enable = true;
    usbtop.enable = true;
    tmux = {
      enable = true;
      clock24 = true;
      extraConfig = ''
        set -g mouse on
        set -g default-terminal "screen-256color"
        set -g status-right "#[fg=black,bg=color15] #{cpu_percentage} %H:%M"
        run-shell ${pkgs.tmuxPlugins.cpu}/share/tmux-plugins/cpu/cpu.tmux
      '';
    };
    ssh = {
      startAgent = lib.mkForce false; # we have to do this for some reason
    };
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
}
