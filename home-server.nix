{
  config,
  pkgs,
  modulesPath,
  ...
}: let
  user = "efrem";
in {
  imports = [
    "${modulesPath}/installer/scan/not-detected.nix"
    ./wireguard-peer.nix
  ];

  services.displayManager.autoLogin = {
    enable = true;
    user = user;
  };

  age.secrets.wg-key-home.file = ./secrets/wg-ws-adder.age;
  # public-key: srov/ElxjM0BPfQHhCFN2sb3UEkwIhFQGSS55P/HIEA=
  wireguard-peer = let
    prefix = config.wireguard-peer.prefix;
  in {
    enable = true;
    ips = ["${prefix}1/128"];
    listenPort = 51820;
    privateKeyFile = config.age.secrets.wg-key-home.path;
    peers = [
      {
        name = "thinkpad";
        publicKey = "wa7WjWFn1SsOLQwOw3EMC1JY29WjU7vLvNlxRtySoTg=";
        allowedIPs = ["${prefix}2/128"];
      }
      {
        name = "phone";
        publicKey = "Y5PxUuaIJi0emIQMkZW5EZDkSAY6Ed4ABAJdGlzpkTI=";
        allowedIPs = ["${prefix}3/128"];
      }
      {
        name = "m1";
        publicKey = "aZEHKJGXFvCe8eOmMCdhD+okIuOkQUULZzKJZ+MWDRU=";
        allowedIPs = ["${prefix}4/128"];
        endpoint = "192.168.1.3:51820";
      }
    ];
  };

  networking.networkmanager.ensureProfiles.profiles = {
    # Bridge device
    br0 = {
      connection = {
        id = "br0";
        type = "bridge";
        interface-name = "br0";
      };
      bridge = {
        stp = true;
      };
      ipv4 = {
        method = "auto"; # DHCP for wired
        route-metric = 100; # lower priority than wifi
      };
      ipv6 = {
        method = "auto";
        route-metric = 100;
      };
    };

    # Bridge member: onboard ethernet
    br0-eno0 = {
      connection = {
        id = "br0-eno0";
        type = "ethernet";
        interface-name = "eno0";
        master = "br0";
        slave-type = "bridge";
      };
    };

    # Bridge member: USB/dock ethernet
    br0-dock = {
      connection = {
        id = "br0-dock";
        type = "ethernet";
        interface-name = "enp45s0u1u4u3u1";
        master = "br0";
        slave-type = "bridge";
      };
    };

    # WiFi - static IP, preferred route
    home-wifi = {
      connection = {
        id = "CiscoKid";
        type = "wifi";
        interface-name = "wlan0";
      };
      wifi = {
        mode = "infrastructure";
        ssid = "CiscoKid";
      };
      ipv4 = {
        method = "manual";
        address1 = "192.168.1.66/24,192.168.1.1";
        dns = "1.1.1.1;1.0.0.1;192.168.1.1;";
        route-metric = 10; # preferred over bridge
      };
      ipv6 = {
        method = "auto";
        route-metric = 10;
      };
    };
  };

  # This is what would go in /etc/ssh/ssh_config in a traditional linux distro
  programs.ssh.extraConfig = ''
    # SSH config for remote home-server
  '';

  nix.buildMachines = let
    mkBuilder = hostName: system: maxJobs: speedFactor: {
      inherit hostName system maxJobs speedFactor;
      sshUser = user;
      sshKey = "/root/.ssh/id_ed25519";
      protocol = "ssh-ng";
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    };
    machines = [
      ["m1" "aarch64-linux" 4 1000]
      # ["j1" "aarch64-linux" 2 1] # Jetson - disabled, too slow/unreliable
    ];
  in
    map (args: mkBuilder (builtins.elemAt args 0) (builtins.elemAt args 1) (builtins.elemAt args 2) (builtins.elemAt args 3)) machines;

  # nix.settings.extra-platforms = ["aarch64-linux"];
  # boot.binfmt.emulatedSystems = ["aarch64-linux"];
  nixpkgs.config.allowUnsupportedSystem = true;

  nix.distributedBuilds = true;
  nix.extraOptions = ''builders-use-substitutes = true'';

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
