{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [./wireguard-peer.nix];

  # Home server's home dir over sshfs, authenticating through the user's
  #  ssh-agent and the `adder-ws` ssh host config.
  systemd.user.services.adder-ws-mount = {
    description = "Mount adder-ws home via sshfs";
    wantedBy = ["default.target"];
    after = ["network-online.target"];
    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/AdderWS";
      ExecStart = ''
        ${pkgs.sshfs}/bin/sshfs -f adder-ws: %h/AdderWS \
          -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,BatchMode=yes
      '';
      ExecStop = "/run/wrappers/bin/fusermount3 -u %h/AdderWS";
      Restart = "on-failure";
      RestartSec = "10s";
      Environment = [
        "SSH_AUTH_SOCK=%t/ssh-agent" # socket from programs.ssh.startAgent
        "PATH=/run/wrappers/bin:${lib.makeBinPath [pkgs.openssh]}"
      ];
    };
  };

  # This is what would go in /etc/ssh/ssh_config in a traditional linux distro
  programs.ssh.extraConfig = ''
    # SSH config for personal laptop
  '';

  # Configure home server as a substituter
  # Priority is set high (1000) so it's only used after public caches
  # This prevents timeout issues while still allowing substitution from home
  nix.settings.substituters = let
    argstr = "trusted=true&compress=true";
  in [
    # "ssh-ng://efrem@home?priority=1000&${argstr}"  # slow due to powerline connection
    "ssh-ng://efrem@m1?priority=500&${argstr}"
  ];
  nix.settings.trusted-public-keys = with (import ./secrets/public-keys.nix); [home-cache-key];
  nix.buildMachines = let
    mkBuilder = hostName: system: maxJobs: speedFactor: {
      inherit hostName system maxJobs speedFactor;
      sshUser = "efrem";
      sshKey = "/root/.ssh/id_ed25519";
      protocol = "ssh-ng";
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    };
    machines = [
      # ["home" "x86_64-linux" 4 100]
      # ["home" "aarch64-linux" 2 100]
      ["m1" "aarch64-linux" 4 100]
      # ["j1" "aarch64-linux" 2 10]
    ];
  in
    map (args: mkBuilder (builtins.elemAt args 0) (builtins.elemAt args 1) (builtins.elemAt args 2) (builtins.elemAt args 3)) machines;

  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
  # boot.binfmt.emulatedSystems = ["aarch64-linux"];
  # nix.settings.extra-platforms = ["aarch64-linux"];
  nixpkgs.config.allowUnsupportedSystem = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandlePowerKey = "suspend";
  };

  # Display note: COSMIC persists output configs per connected-display-set.
  # After running `wlr-randr --output DP-1 --scale 1.5` once with the lid
  # closed, COSMIC saved the correct single-display config (position 0,0,
  # scale 1.5) and now applies it automatically on lid close.

  # Fingerprint reader (disabled for now)
  services.fprintd.enable = false;
  # security.pam.services.cosmic-greeter.text = lib.mkForce ''
  #   auth sufficient ${pkgs.fprintd}/lib/security/pam_fprintd.so max-tries=3 timeout=30
  #   auth sufficient ${pkgs.linux-pam}/lib/security/pam_unix.so likeauth try_first_pass
  # '';

  age.secrets.wg-thinkpad.file = ./secrets/wg-thinkpad.age;
  # public key: wa7WjWFn1SsOLQwOw3EMC1JY29WjU7vLvNlxRtySoTg=
  wireguard-peer = let
    prefix = config.wireguard-peer.prefix;
  in {
    enable = true;
    listenPort = 51820;
    ips = ["${prefix}2/128"];
    privateKeyFile = config.age.secrets.wg-thinkpad.path;
    peers = [
      {
        name = "adderws";
        publicKey = "srov/ElxjM0BPfQHhCFN2sb3UEkwIhFQGSS55P/HIEA=";
        allowedIPs = ["${prefix}1/128"];
        endpoint = "73.15.57.26:55555";
      }
      {
        name = "m1";
        publicKey = "aZEHKJGXFvCe8eOmMCdhD+okIuOkQUULZzKJZ+MWDRU=";
        allowedIPs = ["${prefix}4/128"];
        endpoint = "73.15.57.26:44444";
      }
      # {
      #   name = "phone";
      #   publicKey = "Y5PxUuaIJi0emIQMkZW5EZDkSAY6Ed4ABAJdGlzpkTI=";
      #   allowedIPs = ["${prefix}3/128"];
      # }
    ];
  };
}
