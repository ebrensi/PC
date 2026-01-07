{
  config,
  pkgs,
  modulesPath,
  ...
}: {
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
  # Priority is set high (1000) so it's only used after public caches
  # This prevents timeout issues while still allowing substitution from home
  nix.settings.substituters = let
    argstr = "trusted=true&compress=true";
  in [
    # "ssh-ng://efrem@home?priority=1000&${argstr}"
  ];
  nix.settings.trusted-public-keys = with (import ./secrets/public-keys.nix); [home-cache-key];
  nix.buildMachines = let
    mkBuilder = hostName: system: maxJobs: speedFactor: {
      inherit hostName system maxJobs speedFactor;
      sshUser = "efrem";
      protocol = "ssh-ng";
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    };
    machines = [
      # ["home" "x86_64-linux" 4 100]
      # ["home" "aarch64-linux" 4 100]
      ["m1" "aarch64-linux" 4 10]
      ["jetson" "aarch64-linux" 2 10]
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

  # Fingerprint reader (disabled for now)
  services.fprintd.enable = false;
  # security.pam.services.cosmic-greeter.text = lib.mkForce ''
  #   auth sufficient ${pkgs.fprintd}/lib/security/pam_fprintd.so max-tries=3 timeout=30
  #   auth sufficient ${pkgs.linux-pam}/lib/security/pam_unix.so likeauth try_first_pass
  # '';

  networking.firewall.allowedUDPPorts = [51820];
  age.secrets.wg-thinkpad.file = ./secrets/wg-thinkpad.age;
  # public key: wa7WjWFn1SsOLQwOw3EMC1JY29WjU7vLvNlxRtySoTg=
  networking.wireguard = {
    enable = true;
    interfaces = {
      # network interface name.
      wghome = {
        # the IP address and subnet of this peer
        ips = ["12.167.1.2/32"];

        # WireGuard Port
        # Must be accessible by peers
        listenPort = 51820;
        privateKeyFile = config.age.secrets.wg-thinkpad.path;

        peers = [
          {
            name = "ws-adder";
            publicKey = "srov/ElxjM0BPfQHhCFN2sb3UEkwIhFQGSS55P/HIEA=";
            allowedIPs = [
              "12.167.1.1/32"
            ];
            endpoint = "192.168.1.154:51820";
            #  ToDo: route to endpoint not automatically configured
            # https://wiki.archlinux.org/index.php/WireGuard#Loop_routing
            # https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577
            # Send keepalives every 25 seconds. Important to keep NAT tables alive.
            persistentKeepalive = 25;
          }
        ];
      };
    };
  };
}
