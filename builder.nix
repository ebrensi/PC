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
  ];

  programs = {
    bat.enable = true;
    git.enable = true;
    htop.enable = true;
    tmux = {
      enable = true;
      terminal = "screen-256color";
    };
    # This would go in /etc/ssh/ssh_config in a traditional linux distro
    ssh.extraConfig = ''
      # Base config for all hosts
      Host *
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        ForwardAgent yes
        AddKeysToAgent yes

        # Reuse local ssh connections
        ControlPath /tmp/ssh-%L-%r@%h:%p
        ControlMaster auto
        ControlPersist 1
    '';
  };

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["efrem"];
    substituters = let
      mkArgstr = args: builtins.concatStringsSep "&" (map (k: "${k}=${args.${k}}") (builtins.attrNames args));
      url-args = {
        # see https://nix.dev/manual/nix/2.25/store/types/http-binary-cache-store
        parallel-compression = "true";
        compression = "zstd";
        compression-level = "3";
        path-info-cache-size = "131072";
        want-mass-query = "true";
      };
      args = mkArgstr url-args;
    in [
      "https://guardian-ops-nix.s3.us-west-2.amazonaws.com?${args}&priority=1"
      "https://cache.nixos.org?${args}&priority=10"
    ];
    trusted-public-keys = [
      "guardian-nix-cache:vN2kJ7sUQSbyWv4908FErdTS0VrPnMJtKypt21WzJA0="
    ];
  };
  nix.nixPath = ["nixpkgs=${pkgs.path}"];

  users.users.efrem = {
    isNormalUser = true;
    description = "Efrem Rensi";
    extraGroups = ["networkmanager" "wheel"];
    initialPassword = "p";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII//cI1RPUk4caXbGHdMJpQB7VuydedUCP/Kt9mALxVY Efrem-Laptop"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
