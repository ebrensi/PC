{
  config,
  pkgs,
  ...
}: {
  nix.buildMachines = let
    sshKey = "/home/efrem/.ssh/angelProtection";
    sshUser = "efrem";
    protocol = "ssh-ng";
  in [
    {
      inherit sshKey sshUser protocol;
      hostName = "AP1";
      systems = ["x86_64-linux"];
      maxJobs = 1;
      speedFactor = 2;
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    }

    {
      inherit sshKey sshUser protocol;
      hostName = "jetson";
      systems = ["aarch64-linux"];
      maxJobs = 1;
      speedFactor = 1;
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    }
  ];
  nix.distributedBuilds = true;
  # optional, useful when the builder has a faster internet connection than yours
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';

  # This is what would go in /etc/ssh/ssh_config in a traditional linux distro
  programs.ssh.extraConfig = ''
    # SSH config for remote home-server
    Host jetson
      Hostname jetson-native.local

    Host AP1
      Hostname 100.85.51.6
      User guardian

    Host vm
      Hostname 127.0.0.1
      Port 2222
  '';
}
