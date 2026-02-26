{
  config,
  pkgs,
  modulesPath,
  ...
}: let
  user = "efrem";
  ai = pkgs.writeShellScriptBin "ai" ''
    # Wrapper around aider with interactive model selection via gum filter.
    # Ollama models are fetched live; Claude models are listed statically.
    # All extra args are passed through to aider.

    OLLAMA_MODELS=$(${pkgs.ollama}/bin/ollama list 2>/dev/null \
      | tail -n +2 \
      | awk '{print "ollama/" $1}')

    SELECTED=$(printf '%s\n%s\n' "$OLLAMA_MODELS"  \
      | ${pkgs.gum}/bin/gum filter \
          --placeholder "Select a model..." \
          --height 12)

    [ -z "$SELECTED" ] && exit 0
    exec ${pkgs.aider-chat}/bin/aider --model "$SELECTED" "$@"
  '';
in {
  imports = [
    "${modulesPath}/installer/scan/not-detected.nix"
    ./wireguard-peer.nix
  ];

  services.displayManager.autoLogin = {
    enable = true;
    user = user;
  };

  networking.networkmanager.settings = {
    # Prefer wifi over wired ethernet when both are available
    # since wired connection is a relatively slow Powerline connection
    connection-wifi = {
      match-device = "type:wifi";
      "ipv4.route-metric" = 0;
      "ipv6.route-metric" = 0;
    };
  };
  # Restrict avahi to wifi interface to avoid asynchronous routing problems
  # services.avahi.allowInterfaces = ["wlan0"];

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

  # Static IP for wlan0 via NM profile.
  # Note: iwd handles WiFi auth from /var/lib/iwd/CiscoKid.psk (managed outside Nix).
  # NM+iwd backend can't pass PSK via secret agent, so iwd must know the PSK itself.
  # The PSK here is only needed for NM to recognise this as a WPA2 profile when
  # matching the iwd-initiated connection — NM won't re-authenticate.
  # Trade-off: PSK ends up in the Nix store (world-readable on this machine).
  networking.networkmanager.ensureProfiles.profiles.home-wifi = {
    connection = {
      id = "CiscoKid";
      type = "wifi";
      interface-name = "wlan0";
    };
    wifi = {
      mode = "infrastructure";
      ssid = "CiscoKid";
    };
    wifi-security = {
      key-mgmt = "wpa-psk";
      psk = "demaria1";
    };
    ipv4 = {
      method = "manual";
      address1 = "192.168.1.66/24,192.168.1.1";
      dns = "1.1.1.1;1.0.0.1;192.168.1.1;";
    };
    ipv6 = {
      method = "auto";
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

  # RTX 4050 Mobile — 6 GB VRAM.
  #  Best options
  #  qwen2.5:7b — best general-purpose model that fits comfortably
  #  qwen2.5-coder:7b — if you want coding focus
  #   ollama pull qwen2.5:7b
  # ollama-cuda is broken in current nixpkgs (cuda_compat missing src); use Vulkan instead.
  # VK_ICD_FILENAMES forces the NVIDIA Vulkan ICD so PRIME offload doesn't fall back to Intel.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    # package = pkgs.ollama-cuda;
    host = "0.0.0.0";
    environmentVariables.VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";
  };
  # CUDA binary cache — avoids having to build/fetch CUDA redist packages from source
  nix.settings = {
    substituters = ["https://cuda-maintainers.cachix.org"];
    trusted-public-keys = ["cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="];
  };

  # Configuration for Aider to work
  environment.systemPackages = with pkgs; [ai aider-chat opencode qwen-code];
  environment.etc."aider/aider.conf.yml".text = ''
    model: ollama/qwen2.5-coder:7b
  '';
  environment.etc."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    # model = "anthropic/claude-sonnet-4-5";
    # small_model = "ollama/qwen2.5-coder:7b";
    model = "ollama/qwen2.5-coder:7b";
    provider = {
      anthropic.options.apiKey = "{env:ANTHROPIC_API_KEY}";
      ollama = {
        npm = "@ai-sdk/openai-compatible";
        name = "Ollama";
        options.baseURL = "http://localhost:11434/v1";
        models."qwen2.5-coder:7b".name = "Qwen 2.5 Coder 7B";
      };
    };
  };

  environment.etc."qwen/settings.json".text = builtins.toJSON {
    modelProviders.openai = [
      {
        id = "qwen2.5-coder:7b";
        name = "Local qwen2.5-coder";
        baseUrl = "http://localhost:11434/v1";
        envKey = "OLLAMA_API_KEY";
      }
    ];
    env.OLLAMA_API_KEY = "ollama";
    security.auth.selectedType = "openai";
    model.name = "qwen2.5-coder:7b";
  };

  systemd.tmpfiles.rules = [
    "L+ /home/${user}/.aider.conf.yml 644 ${user} users - /etc/aider/aider.conf.yml"
    "d  /home/${user}/.config/opencode 755 ${user} users -"
    "L+ /home/${user}/.config/opencode/opencode.json 644 ${user} users - /etc/opencode/opencode.json"
  ];

  # qwen-code writes a version field back to settings.json, so it must be a
  # real writable file — not a symlink into the read-only Nix store.
  # Copy on every activation so nix config changes still propagate.
  system.activationScripts.qwen-settings.text = ''
    install -Dm644 /etc/qwen/settings.json /home/${user}/.qwen/settings.json
    chown ${user}:users /home/${user}/.qwen/settings.json
  '';
  networking.firewall.allowedTCPPorts = [11434];
  environment.sessionVariables = {
    OLLAMA_API_BASE = "http://localhost:11434";
  };
}
