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

  nix.optimise = {
    automatic = true;
    dates = ["03:45"];
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # See https://discourse.nixos.org/t/timezones-how-to-setup-on-a-laptop/33853/7
  # services.tzupdate.enable = true;
  services.automatic-timezoned.enable = true;
  services.geoclue2.geoProviderUrl = "https://api.beacondb.net/v1/geolocate";

  # Allow unfree packages (needed for NVIDIA drivers and some software)
  nixpkgs.config.allowUnfree = true;

  # System packages
  environment.systemPackages = with pkgs; [
    # see https://search.nixos.org/packages?channel=unstable

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
    tig

    # Networking
    networkmanagerapplet

    # Utilities
    wl-clipboard-x11
    wl-clipboard-rs
    trash-cli
  ];

  # https://search.nixos.org/options?channel=unstable&query=programs
  programs = {
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
      plugins = [pkgs.tmuxPlugins.cpu];
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
  };

  services.tailscale.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = false;
    ipv6 = false;
    openFirewall = true;

    # see https://linux.die.net/man/5/avahi-daemon.conf
    publish = {
      enable = true;
      userServices = true;
      addresses = true;
    };
  };

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["@wheel"];
  };
  system.stateVersion = "25.05";
}
