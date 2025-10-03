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

    Host t1
      Hostname 192.168.1.95

    Host t2
      Hostname 192.168.1.91

    Host m1
      Hostname 192.168.1.162
  '';

  nix.buildMachines = let
    sshKey = "/home/efrem/.ssh/angelProtection";
    sshUser = "efrem";
    protocol = "ssh-ng";
    supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
  in [
    {
      inherit sshKey sshUser protocol supportedFeatures;
      hostName = "AP1";
      system = "x86_64-linux";
      maxJobs = 32;
      speedFactor = 4;
    }
    {
      inherit sshKey sshUser protocol supportedFeatures;
      hostName = "t1";
      system = "x86_64-linux";
      maxJobs = 1;
      speedFactor = 1;
    }
    {
      inherit sshKey sshUser protocol supportedFeatures;
      hostName = "t2";
      system = "x86_64-linux";
      maxJobs = 1;
      speedFactor = 1;
    }

    {
      inherit sshKey sshUser protocol supportedFeatures;
      hostName = "AP1";
      system = "aarch64-linux";
      maxJobs = 8;
      speedFactor = 1;
    }

    {
      inherit sshKey sshUser protocol supportedFeatures;
      hostName = "m1";
      system = "aarch64-linux";
      maxJobs = 8;
      speedFactor = 4;
    }
  ];
  nix.distributedBuilds = true;
  # optional, useful when the builder has a faster internet connection than yours
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
}
