{
  config,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [./wireguard-peer.nix];

  # This is what would go in /etc/ssh/ssh_config in a traditional linux distro
  programs.ssh.extraConfig = ''
    # SSH config for personal laptop
    Host vm
      Hostname 127.0.0.1
      Port 2222
  '';

  boot.binfmt.emulatedSystems = ["aarch64-linux"];
  nix.settings.extra-platforms = ["aarch64-linux"];

  # Configure home server as a substituter
  # Priority is set high (1000) so it's only used after public caches
  # This prevents timeout issues while still allowing substitution from home
  nix.settings.substituters = let
    argstr = "trusted=true&compress=true";
  in [
    # "ssh-ng://efrem@adder-ws?priority=1000&${argstr}"
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
      # ["m1" "aarch64-linux" 4 10]
      # ["j1" "aarch64-linux" 2 10]
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

  age.secrets.wg-thinkpad.file = ./secrets/wg-thinkpad.age;
  # public key: wa7WjWFn1SsOLQwOw3EMC1JY29WjU7vLvNlxRtySoTg=
  wireguard-peer = {
    listenPort = 51820;
    interface = "wghome";
    ips = ["12.167.1.3/32" "fd42:af9e:1c7d:8b3a:1291:d1ff:fe9e:32c0/128"];
    privateKeyFile = config.age.secrets.wg-thinkpad.path;
    peers = [
      {
        name = "relay";
        publicKey = "qtyeOtl/yxdpsELc8xdcC6u0a1p+IZU0HwHrHhUpGxc=";
        # Route all VPN traffic (IPv6 only) through relay
        allowedIPs = ["12.167.1.0/24" "fd42:af9e:1c7d:8b3a::/64"];
        # endpoint = "73.15.57.26:51820"; # Public IP for roaming
        endpoint = "t2.local:51820";
        persistentKeepalive = 25;
      }
      # {
      #   # name = "adderws";
      #   publicKey = "srov/ElxjM0BPfQHhCFN2sb3UEkwIhFQGSS55P/HIEA=";
      #   allowedIPs = ["12.167.1.2/32" "fd39:8ed9:8f8a:1ef2:dd0a:f2af:7af1:ea6d/128"];
      #   # endpoint = "adder-ws.local:51820";
      #   persistentKeepalive = 25;
      # }
    ];
  };
  networking.extraHosts = ''
    fd42:af9e:1c7d:8b3a:d693:90ff:fe28:5167 adder-ws
    fd42:af9e:1c7d:8b3a:b241:6fff:fe14:8a72 t2
  '';
}
