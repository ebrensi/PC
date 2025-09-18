{
  config,
  pkgs,
  ...
}: {
  nix.buildMachines = [
    {
      hostName = "AP1";
      sshUser = "efrem";
      protocol = "ssh-ng";
      sshKey = "/home/efrem/.ssh/angelProtection.pub";
      # publicHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKFLP5Wgaa6DMRu6Eld+De5FyOp0UVIZz/CGj2uaYnF8 root@nixos";
      systems = ["x86_64-linux"];
      maxJobs = 1;
      speedFactor = 2;
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      # mandatoryFeatures = [];
    }

    {
      hostName = "jetson-native.local";
      sshUser = "efrem";
      protocol = "ssh-ng";
      sshKey = "/home/efrem/.ssh/angelProtection.pub";
      systems = ["aarch64-linux"];
      maxJobs = 1;
      speedFactor = 1;
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      # mandatoryFeatures = [];
    }
  ];
  nix.distributedBuilds = true;
  # optional, useful when the builder has a faster internet connection than yours
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
}
