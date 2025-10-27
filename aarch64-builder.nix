# Generic builder profile
#  This is a machine used for building Nix packages and systems remotely.
{
  config,
  lib,
  pkgs,
  ...
}: {
  networking = {
    # networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [22];
    };
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        AllowAgentForwarding = true;
      };
    };

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

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # see https://search.nixos.org/packages?channel=unstable
    autossh
    btop
    nnn
    nix-output-monitor
    fastfetch
    micro
    speedtest-cli

    pv # progress viewer for long aws uploads
    awscli2 # For building & publishing Vision Docker image
    zstd # Compression for docker image tarball
    openssl # For SHA256 checksum generation
    go # For VERSION calculation via svu tool
    gnumake # Make build tool
    bashInteractive
    uv # Python dependency management tool
    coreutils
    python3 # needed by uv for pip compile
    gcc
  ];

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    package = pkgs.docker_28; # TODO: Remove this when nixpkgs updates to a newer docker
  };

  programs = {
    starship.enable = true;
    bat.enable = true;
    git.enable = true;
    htop.enable = true;
    tmux = {
      clock24 = true;
      terminal = "screen-256color";
      plugins = [
        pkgs.tmuxPlugins.cpu
        pkgs.tmuxPlugins.continuum
      ];
      extraConfig = ''
        set -g mouse on
        set -g status-right "#[fg=black,bg=color15] #{cpu_percentage} %H:%M"
        run-shell ${pkgs.tmuxPlugins.cpu}/share/tmux-plugins/cpu/cpu.tmux
      '';
    };
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

  age.secrets.aws-credentials = {
    file = ./secrets/aws-credentials.age;
    path = "/home/efrem/.aws/credentials";
    mode = "644";
    owner = "efrem";
  };

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["efrem"];
    substituters = [
      "https://cache.nixos.org?priority=0"
      "https://guardian-ops-nix.s3.us-west-2.amazonaws.com?priority=1"
    ];
    trusted-public-keys = [
      "guardian-nix-cache:vN2kJ7sUQSbyWv4908FErdTS0VrPnMJtKypt21WzJA0="
    ];
  };
  nix.nixPath = ["nixpkgs=${pkgs.path}"];

  users.users.efrem = {
    isNormalUser = true;
    description = "Efrem Rensi";
    extraGroups = ["networkmanager" "wheel" "docker"];
    initialPassword = "p";
    openssh.authorizedKeys.keys = with (import ./secrets/public-keys.nix); [personal-ssh-key];
  };
  security.sudo.wheelNeedsPassword = false;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
