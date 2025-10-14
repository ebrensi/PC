{
  config,
  pkgs,
  modulesPath,
  ...
}: {
  imports = with nixos-hardware.nixosModules; [
    "${modulesPath}/installer/scan/not-detected.nix"
  ];
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

    Host jetson
      Hostname 192.168.1.156
  '';

  nix.buildMachines = let
    mkBuilder = hostName: system: maxJobs: speedFactor: {
      inherit hostName system maxJobs speedFactor;
      sshKey = "/home/efrem/.ssh/angelProtection";
      sshUser = "efrem";
      protocol = "ssh-ng";
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    };
    machines = [
      ["t1" "x86_64-linux" 1 2]
      ["t2" "x86_64-linux" 1 2]
      #
      ["m1" "aarch64-linux" 8 4]
      # ["t1" "aarch64-linux" 1 2]
      # ["t2" "aarch64-linux" 1 2]
    ];
  in
    map (args: mkBuilder (builtins.elemAt args 0) (builtins.elemAt args 1) (builtins.elemAt args 2) (builtins.elemAt args 3)) machines;

  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
}
