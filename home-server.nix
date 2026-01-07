{
  config,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/scan/not-detected.nix"
  ];

  services.displayManager.autoLogin = {
    enable = true;
    user = "efrem";
  };

  # nix.settings.extra-platforms = ["aarch64-linux"];
  # boot.binfmt.emulatedSystems = ["aarch64-linux"];
  nixpkgs.config.allowUnsupportedSystem = true;

  networking.networkmanager.settings = {
    # Prefer wifi over wired ethernet when both are available
    # since wired connection is a relatively slow Powerline connection
    connection-wifi = {
      match-device = "type:wifi";
      "ipv4.route-metric" = 0;
      "ipv6.route-metric" = 0;
    };
  };

  networking.firewall.allowedUDPPorts = [51820];
  age.secrets.wg-key-home.file = ./secrets/wg-ws-adder.age;
  # public-key: srov/ElxjM0BPfQHhCFN2sb3UEkwIhFQGSS55P/HIEA=
  networking.wireguard = {
    enable = true;
    interfaces = {
      # network interface name.
      wghome = {
        # the IP address and subnet of this peer
        ips = ["12.167.1.1/32"];

        # WireGuard Port
        # Must be accessible by peers
        listenPort = 51820;
        privateKeyFile = config.age.secrets.wg-key-home.path;

        peers = [
          {
            name = "thinkpad";
            publicKey = "wa7WjWFn1SsOLQwOw3EMC1JY29WjU7vLvNlxRtySoTg=";
            allowedIPs = [
              "12.167.1.2/32"
            ];
            #   endpoint = "192.168.1.56:51820";
            #  ToDo: route to endpoint not automatically configured
            # https://wiki.archlinux.org/index.php/WireGuard#Loop_routing
            # https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577
            # Send keepalives every 25 seconds. Important to keep NAT tables alive.
            # persistentKeepalive = 25;
          }
        ];
      };
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
      Hostname 192.168.1.217

    Host m1
      Hostname 192.168.1.162

    Host j1
      Hostname 192.168.1.156

    Host thinkpad
      Hostname 100.106.204.20
  '';

  nix.buildMachines = let
    mkBuilder = hostName: system: maxJobs: speedFactor: {
      inherit hostName system maxJobs speedFactor;
      sshUser = "efrem";
      sshKey = "/home/efrem/.ssh/id_ed25519";
      protocol = "ssh-ng";
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    };
    machines = [
      # ["t1" "x86_64-linux" 1 100]
      # ["t2" "x86_64-linux" 1 100]
      # ["AP1" "x86_64-linux" 4 100]
      ["m1" "aarch64-linux" 4 1000]
    ];
  in
    (map (args: mkBuilder (builtins.elemAt args 0) (builtins.elemAt args 1) (builtins.elemAt args 2) (builtins.elemAt args 3)) machines)
    ++ [
      {
        hostName = "j1"; # Your Jetson or remote builder
        sshUser = "efrem";
        sshKey = "/home/efrem/.ssh/id_ed25519";
        protocol = "ssh-ng";
        system = "aarch64-linux";
        maxJobs = 2;
        speedFactor = 1;
        supportedFeatures = ["big-parallel"];
        mandatoryFeatures = [];
      }
    ];

  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';

  # This is for using this machine as a nix cache server
  #  any files built here are signed with this private key
  # Temporarily disabled due to encryption issues
  # age.secrets.home-nix-cache.file = ./secrets/home-nix-cache.age;
  # nix.settings.secret-key-files = [config.age.secrets.home-nix-cache.path];

  # Set a consistent mount point for my external USB drive
  #  connected via USB to thundebolt dock
  fileSystems."/mnt/sandisk" = {
    device = "/dev/disk/by-uuid/EADF-760A";
    fsType = "exfat";
    options = ["nofail" "x-systemd.automount" "x-systemd.device-timeout=5" "noatime"];
  };
  # Enable exFAT filesystem support for this USB drive
  boot.supportedFilesystems = ["exfat"];

  # This is a laptop machine acting as a server so we don't want it to sleep
  # When hooked to a dock or external power
  services.logind.settings.Login = {
    # Dont sleep when lid is closed on external power
    HandleLidSwitchExternalPower = "ignore";
    # Dont sleep when lid is closed we are connected to a docking station
    HandleLidSwitchDocked = "ignore";
  };
}
