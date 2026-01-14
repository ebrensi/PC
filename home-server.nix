{
  config,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/scan/not-detected.nix"
    ./wireguard-peer.nix
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

  age.secrets.wg-key-home.file = ./secrets/wg-ws-adder.age;
  # public-key: srov/ElxjM0BPfQHhCFN2sb3UEkwIhFQGSS55P/HIEA=
  wireguard-peer = {
    interface = "wghome";
    ips = ["12.167.1.2/32" "fd42:af9e:1c7d:8b3a:d693:90ff:fe28:5167/128"];
    listenPort = 51820;
    privateKeyFile = config.age.secrets.wg-key-home.path;
    peers = [
      {
        name = "relay";
        publicKey = "qtyeOtl/yxdpsELc8xdcC6u0a1p+IZU0HwHrHhUpGxc=";
        # Route all VPN traffic (IPv6 only) through relay
        allowedIPs = ["12.167.1.0/24" "fd42:af9e:1c7d:8b3a::/64"];
        endpoint = "t2.local:51820"; # this machine is always on the same LAN
      }
      # {
      #   # name = "thinkpad";
      #   publicKey = "wa7WjWFn1SsOLQwOw3EMC1JY29WjU7vLvNlxRtySoTg=";
      #   allowedIPs = ["12.167.1.3/32" "fd39:8ed9:8f8a:1ef2:48bc:4627:74f7:c15c/128"];
      #   # endpoint = "thinkpad.local:51820";
      #   persistentKeepalive = 25;
      # }
    ];
  };
  networking.extraHosts =
    ''
      fd42:af9e:1c7d:8b3a:1291:d1ff:fe9e:32c0 thinkpad
      fd42:af9e:1c7d:8b3a:b241:6fff:fe14:8a72 t2
    ''
    + "\n"
    + (import /home/efrem/dev/Guardian/provision/nix/packages/guardian-hosts.nix {inherit (pkgs) lib;});

  # This is what would go in /etc/ssh/ssh_config in a traditional linux distro
  programs.ssh.extraConfig = ''
    # SSH config for remote home-server

    Host vm
      Hostname 127.0.0.1
      Port 2222
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
      ["m1.local" "aarch64-linux" 4 1000]
    ];
  in
    (map (args: mkBuilder (builtins.elemAt args 0) (builtins.elemAt args 1) (builtins.elemAt args 2) (builtins.elemAt args 3)) machines)
    ++ [
      {
        hostName = "j1.local"; # Your Jetson or remote builder
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

  # Set a consistent mount point for my external USB drive
  #  connected via USB to thundebolt dock
  fileSystems."/mnt/sandisk" = {
    device = "/dev/disk/by-uuid/EADF-760A";
    fsType = "exfat";
    options = ["nofail" "x-systemd.automount" "x-systemd.device-timeout=5" "noatime"];
  };
  # Enable exFAT filesystem support for this USB drive
  boot.supportedFilesystems = ["exfat"];

  # services.avahi.denyInterfaces = ["eno0"];

  # This is a laptop machine acting as a server so we don't want it to sleep
  # When hooked to a dock or external power
  services.logind.settings.Login = {
    # Dont sleep when lid is closed on external power
    HandleLidSwitchExternalPower = "ignore";
    # Dont sleep when lid is closed we are connected to a docking station
    HandleLidSwitchDocked = "ignore";
  };
  # prevent system from auto-sleeping
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
}
