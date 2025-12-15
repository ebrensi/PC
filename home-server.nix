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

  nix.settings.extra-platforms = ["aarch64-linux"];
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
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

    Host jetson
      Hostname 192.168.1.156

    Host thinkpad
      Hostname 100.106.204.20
  '';

  nix.buildMachines = let
    mkBuilder = hostName: system: maxJobs: speedFactor: {
      inherit hostName system maxJobs speedFactor;
      sshUser = "efrem";
      protocol = "ssh-ng";
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    };
    machines = [
      # ["t1" "x86_64-linux" 1 100]
      # ["t2" "x86_64-linux" 1 100]
      # ["AP1" "x86_64-linux" 4 100]
      #
      ["m1" "aarch64-linux" 8 1000]
    ];
  in
    (map (args: mkBuilder (builtins.elemAt args 0) (builtins.elemAt args 1) (builtins.elemAt args 2) (builtins.elemAt args 3)) machines)
    ++ [
      {
        hostName = "jetson"; # Your Jetson or remote builder
        sshUser = "efrem";
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
  age.secrets.home-nix-cache.file = ./secrets/home-nix-cache.age;
  nix.settings.secret-key-files = [config.age.secrets.home-nix-cache.path];

  # Set a consistent mount point for my external USB drive
  #  connected via USB to thundebolt dock
  fileSystems."/mnt/usb_sandisk_1T" = {
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

  # Headscale - self-hosted Tailscale control server
  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 8080;
    settings = {
      # see https://github.com/juanfont/headscale/blob/main/config-example.yaml

      server_url = "http://73.15.57.26:8080"; # Your public IP
      listen_addr = "0.0.0.0:8080";

      # Networking settings
      prefixes.v4 = "100.64.0.0/10"; # Tailscale IPv4 range

      # DNS settings
      dns = {
        base_domain = "home.arpa";
        nameservers.global = ["1.1.1.1" "8.8.8.8"];
        magic_dns = true;
      };
    };
  };

  # Security for headscale service
  #  Monitoring options:

  # 1. Monitor Headscale Logs (Real-time)
  # journalctl -u headscale -f                    # Follow logs
  # journalctl -u headscale --since "1 hour ago"  # Last hour
  # journalctl -u headscale | grep -i error       # Errors only

  # 2. Monitor Active Connections (Live)
  # # Watch connections to port 8080
  # watch -n 1 'ss -tn state established "( dport = :8080 or sport = :8080 )"'

  # # Show all connections with IP addresses
  # ss -tnp | grep :8080

  # Then monitor with:
  # journalctl -k -f | grep HEADSCALE  # Kernel logs for port 8080

  # 4. Packet Capture (Deep Inspection)
  # # Capture all traffic on port 8080
  # sudo tcpdump -i any port 8080 -n

  # # Save to file for later analysis
  # sudo tcpdump -i any port 8080 -w /tmp/port8080.pcap

  # Open firewall for headscale
  networking.firewall = {
    allowedTCPPorts = [8080];
    # Log dropped packets (potential attacks)
    # logRefusedPackets = true;

    # Custom rules to log accepted connections on 8080
    extraCommands = ''
          iptables -A INPUT -p tcp --dport 8080 -j LOG --log-prefix "HEADSCALE: "
      --log-level 4
    '';
  };

  # Rate limiting with fail2ban
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";

    # Ignore Tailscale/Headscale IP range to prevent banning trusted devices
    ignoreIP = [
      "127.0.0.0/8"      # localhost
      "192.168.0.0/16"   # local network
      "100.64.0.0/10"    # Tailscale/Headscale range
    ];

    jails = {
      headscale = ''
        enabled = true
        filter = headscale
        port = 8080
        logpath = /var/log/headscale/headscale.log
        maxretry = 10
        findtime = 600
        bantime = 3600
      '';
    };
  };

  # Fail2ban filter for headscale
  environment.etc."fail2ban/filter.d/headscale.conf" = {
    text = ''
      [Definition]
      failregex = ^.*Failed authentication.*from <HOST>.*$
                  ^.*Invalid key.*from <HOST>.*$
      ignoreregex =
    '';
  };
}
