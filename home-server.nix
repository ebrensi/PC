{
  config,
  pkgs,
  ...
}: {
  nix.settings.extra-platforms = ["aarch64-linux"];
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

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
      systems = ["x86_64-linux" "aarch64-linux"];
      maxJobs = 32;
      speedFactor = 3;
    }

    {
      inherit sshKey sshUser protocol supportedFeatures;
      hostName = "jetson";
      systems = ["aarch64-linux"];
      maxJobs = 1;
      speedFactor = 1;
    }

    # {
    #   inherit sshKey sshUser protocol supportedFeatures;
    #   hostName = "t1";
    #   systems = ["x86_64-linux"];
    #   maxJobs = 8;
    #   speedFactor = 1;
    # }

    # {
    #   inherit sshKey sshUser protocol supportedFeatures;
    #   hostName = "t2";
    #   systems = ["x86_64-linux"];
    #   maxJobs = 1;
    #   speedFactor = 1;
    # }
  ];
  nix.distributedBuilds = true;
  # optional, useful when the builder has a faster internet connection than yours
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
}
