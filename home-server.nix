{
  config,
  pkgs,
  ...
}: {
  nix.settings.extra-platforms = ["aarch64-linux"];
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  networking.networkmanager.settings = {
    # Prefer wifi over wired ethernet when both are available
    # since wired connection is a relatively slow Powerline connection
    connection-wifi = {
      match-device = "type:wifi";
      "ipv4.route-metric" = 0;
      "ipv6.route-metric" = 0;
    };
  };

  # This is what would go in /etc/ssh/ssh_config in a traditional linux distro
  programs.ssh.extraConfig = ''
    # SSH config for remote home-server
    Host jetson
      Hostname jetson-native.local

    Host AP1
      Hostname 100.85.51.6

    Host vm
      Hostname 127.0.0.1
      Port 2222

    # Host t1
    #   # Hostname 192.168.1.95
    #   Hostname t1.local

    # Host t2
    #   # Hostname 192.168.1.91
    #   Hostname t2.local

    # Host m1
    #   # Hostname 192.168.1.162
    #   Hostname m1.local

    Hostname t1 t2 m1
      Hostname %h.local
  '';

  nix.buildMachines = let
    sshKey = "/home/efrem/.ssh/angelProtection";
    base = {
      sshUser = "efrem";
      protocol = "ssh-ng";
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    };
    machines = [
      {
        hostName = "AP1";
        system = "x86_64-linux";
        maxJobs = 32;
        speedFactor = 4;
      }
      {
        hostName = "t1";
        system = "x86_64-linux";
        maxJobs = 2;
        speedFactor = 1;
      }
      {
        hostName = "t2";
        system = "x86_64-linux";
        maxJobs = 2;
        speedFactor = 1;
      }

      {
        hostName = "AP1";
        system = "aarch64-linux";
        maxJobs = 8;
        speedFactor = 1;
      }

      {
        hostName = "m1";
        system = "aarch64-linux";
        maxJobs = 8;
        speedFactor = 4;
      }
    ];
  in
    map (m: m // base) machines;

  nix.distributedBuilds = true;
  # optional, useful when the builder has a faster internet connection than yours
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
}
