{
  config,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/scan/not-detected.nix"
  ];
  # This is what would go in /etc/ssh/ssh_config in a traditional linux distro
  programs.ssh.extraConfig = ''
    # SSH config for personal laptop
    Host vm
      Hostname 127.0.0.1
      Port 2222

    Host home
      Hostname 100.108.117.58

    Host t1 t2 m1 jetson
        Hostname %h.local
        ProxyJump home

    Host AP1
      Hostname 100.85.51.6
  '';

  boot.binfmt.emulatedSystems = ["aarch64-linux"];
  nix.settings.extra-platforms = ["aarch64-linux"];

  # Configure home server as a substituter
  # Priority is set high (100) so it's only used after public caches
  # This prevents timeout issues while still allowing substitution from home
  nix.settings.substituters = [
    "ssh-ng://efrem@home?priority=100"
  ];
  nix.settings.trusted-public-keys = with (import ./secrets/public.nix); [home-cache-key];
  nix.buildMachines = let
    mkBuilder = hostName: system: maxJobs: speedFactor: {
      inherit hostName system maxJobs speedFactor;
      sshUser = "efrem";
      protocol = "ssh-ng";
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    };
    machines = [
      ["home" "x86_64-linux" 4 4]
      ["t1" "x86_64-linux" 1 1]
      ["t2" "x86_64-linux" 1 1]
      #
      ["m1" "aarch64-linux" 8 4]
      ["home" "aarch64-linux" 2 4]
    ];
  in
    map (args: mkBuilder (builtins.elemAt args 0) (builtins.elemAt args 1) (builtins.elemAt args 2) (builtins.elemAt args 3)) machines;

  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandlePowerKey = "suspend";
  };
}
