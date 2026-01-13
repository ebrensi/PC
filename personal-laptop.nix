{
  config,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    ./wg-endpoint-discovery.nix
  ];

  # This is what would go in /etc/ssh/ssh_config in a traditional linux distro
  programs.ssh.extraConfig = ''
    # SSH config for personal laptop
    Host vm
      Hostname 127.0.0.1
      Port 2222

    Host t1 m1 j1
      Hostname %h.local
      ProxyJump adder-ws
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

  networking.firewall = {
    allowedUDPPorts = [51820];
    trustedInterfaces = ["wghome"];
    checkReversePath = false;
  };
  age.secrets.wg-thinkpad.file = ./secrets/wg-thinkpad.age;
  # public key: wa7WjWFn1SsOLQwOw3EMC1JY29WjU7vLvNlxRtySoTg=
  networking.wireguard = {
    interfaces = {
      wghome = {
        ips = ["12.167.1.3/32" "2601:643:867f:b080::1000/128"];
        listenPort = 51820;
        privateKeyFile = config.age.secrets.wg-thinkpad.path;
        peers = [
          {
            name = "relay";
            publicKey = "qtyeOtl/yxdpsELc8xdcC6u0a1p+IZU0HwHrHhUpGxc=";
            allowedIPs = ["12.167.1.0/24" "2601:643:867f:b080::/64"];
            # endpoint = "73.15.57.26:51820"; # Public IP for roaming
            endpoint = "t2.local:51820";
            persistentKeepalive = 25;
          }
          # {
          #   # name = "adderws";
          #   publicKey = "srov/ElxjM0BPfQHhCFN2sb3UEkwIhFQGSS55P/HIEA=";
          #   allowedIPs = ["12.167.1.2/32" "2601:643:867f:b080:8693:1960:e347:ff06/128"];
          #   # endpoint = "adder-ws.local:51820";
          #   persistentKeepalive = 25;
          # }
        ];
      };
    };
  };
  networking.extraHosts = ''
    12.167.1.2 adder-ws
    12.167.1.1 t2
  '';

  # Fix IPv6 route metrics to prioritize WireGuard over RA routes
  systemd.services.wireguard-wghome-fix-routes = {
    description = "Fix WireGuard IPv6 route metrics";
    after = ["wireguard-wghome.service"];
    wants = ["wireguard-wghome.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      # Wait for WireGuard to create its routes
      sleep 2

      # Fix route metrics for all IPv6 routes on wghome interface
      ${pkgs.iproute2}/bin/ip -6 route show dev wghome | while read route; do
        dest=$(echo "$route" | ${pkgs.gawk}/bin/awk '{print $1}')
        ${pkgs.iproute2}/bin/ip -6 route del "$dest" dev wghome 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip -6 route add "$dest" dev wghome metric 50
      done
    '';
  };
}
