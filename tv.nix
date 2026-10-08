# TV appliance profile: a cast target, not a media center.
#
# The screen sits on YouTube's TV interface (youtube.com/tv) in a fullscreen
#  browser. Nothing is browsed on the TV itself; phones push to it from the
#  YouTube app: Cast > "Link with TV code" (code from the TV's Settings page).
#  Desktop Chrome finds it on the LAN via DIAL (tv-dial.py), like a smart TV.
#
# It runs inside a minimal sway session that owns tty1, the way a display
#  manager would.
{
  config,
  lib,
  pkgs,
  ...
}: let
  user = "efrem";
  kiosk = "tv";
  public-keys = import ./secrets/public-keys.nix;

  # youtube.com/tv redirects desktop browsers to the regular site; a TV user
  #  agent keeps the remote-friendly TV interface and its phone pairing. It is
  #  in the format of YouTube's own TV runtime (Cobalt), whose "(Brand, Model,
  #  Connection)" part names this screen in the phone's cast list. A Samsung
  #  Tizen user agent here made it show up as "Samsung Smart TV".
  tvUserAgent = "Mozilla/5.0 (X11; Linux aarch64) Cobalt/25.lts.30.1034943-gold (unlike Gecko) v8/8.8.278.17-jit gles Starboard/15, OrangePi_RK3588_2026/1.0 (Orange Pi, TV, Wired)";

  # tv-dial steers the kiosk tab over the DevTools protocol (localhost only).
  #  Chrome ignores --remote-debugging-port on its default profile directory,
  #  hence the explicit one.
  cdpPort = 9222;
  dialPort = 56790;

  browser = lib.escapeShellArgs [
    (lib.getExe pkgs.chromium)
    "--kiosk"
    "--user-data-dir=/var/lib/${kiosk}/chromium"
    "--remote-debugging-port=${toString cdpPort}"
    "--ozone-platform=wayland"
    "--user-agent=${tvUserAgent}"
    "--autoplay-policy=no-user-gesture-required"
    "--no-first-run"
    "--noerrdialogs"
    "--disable-session-crashed-bubble"
    "--password-store=basic"
    "https://www.youtube.com/tv"
  ];

  swayConfig = pkgs.writeText "tv-sway.conf" ''
    output * bg #000000 solid_color
    default_border none
    seat * hide_cursor 3000
    exec ${browser}
  '';
in {
  # Admin account. This box deliberately skips user-efrem.nix: a TV has no use
  #  for the dev repos it clones or the AWS/Guardian credentials it decrypts.
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = ["wheel" "video" "audio"];
    initialPassword = "password";
    openssh.authorizedKeys.keys = with public-keys; [personal-ssh-key phone-ssh-key];
  };
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [user]; # so deploy-binaries can copy closures in

  # The kiosk session's user. The browser profile (YouTube pairing) lives in
  #  its home.
  users.users.${kiosk} = {
    isNormalUser = true;
    home = "/var/lib/${kiosk}";
    extraGroups = ["video" "render" "input" "audio"];
  };

  systemd.services.tv-session = {
    description = "TV kiosk session (sway + YouTube TV)";
    after = ["systemd-user-sessions.service" "network-online.target"];
    wants = ["network-online.target"];
    conflicts = ["getty@tty1.service"];
    wantedBy = ["multi-user.target"];
    environment.XDG_SESSION_TYPE = "wayland";
    serviceConfig = {
      User = kiosk;
      # A PAM login session on tty1 gives sway a logind seat (DRM master,
      #  input devices) and starts the user's PipeWire.
      PAMName = "login";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
      StandardInput = "tty";
      StandardOutput = "journal";
      ExecStart = "${lib.getExe pkgs.sway} --config ${swayConfig}";
      Restart = "always";
      RestartSec = 2;
    };
  };
  # tty1 belongs to the kiosk. Without this, logind spawns a login prompt there
  #  whenever the VT frees up (e.g. mid-switch), and since the two conflict, the
  #  prompt stops tv-session. Rescue logins: tty2 (Ctrl+Alt+F2) or ssh.
  systemd.services."getty@tty1".enable = false;
  programs.sway.enable = true; # session plumbing: polkit, xdg portals, fonts

  # DIAL server: makes the TV show up in desktop Chrome's cast list. Desktops
  #  also need graphical.nix's firewall rule to receive the SSDP replies.
  systemd.services.tv-dial = let
    tv-dial = pkgs.writers.writePython3Bin "tv-dial" {
      libraries = [pkgs.python3Packages.websockets];
      flakeIgnore = ["E501"];
    } (builtins.readFile ./tv-dial.py);
  in {
    description = "DIAL server for casting YouTube to the TV";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    environment = {
      FRIENDLY_NAME = "Efrem's OrangePi TV"; # shown in Chrome's cast list, to everyone on the LAN
      HTTP_PORT = toString dialPort;
      CDP_PORT = toString cdpPort;
    };
    serviceConfig = {
      ExecStart = "${tv-dial}/bin/tv-dial";
      Restart = "always";
      RestartSec = 2;
      DynamicUser = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
    };
  };
  # Parks the kiosk tab on a blank page while the TV is off (HDMI-CEC), so
  #  nobody streams YouTube to a dark screen.
  systemd.services.tv-power-watch = let
    tv-power-watch = pkgs.writers.writePython3Bin "tv-power-watch" {
      libraries = [pkgs.python3Packages.websockets];
      flakeIgnore = ["E501"];
    } (builtins.readFile ./tv-power-watch.py);
  in {
    description = "Stop YouTube while the TV is off";
    wantedBy = ["multi-user.target"];
    path = [pkgs.v4l-utils]; # cec-ctl
    environment.CDP_PORT = toString cdpPort;
    serviceConfig = {
      ExecStart = "${tv-power-watch}/bin/tv-power-watch";
      Restart = "always";
      RestartSec = 10;
      DynamicUser = true;
      SupplementaryGroups = ["video"]; # /dev/cec*
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
    };
  };

  networking.firewall = {
    allowedUDPPorts = [1900]; # SSDP M-SEARCH
    allowedTCPPorts = [dialPort];
  };

  # Sound only over HDMI. The board's analog codec (headphone jack) is the
  #  first ALSA card, so it would otherwise win the default-sink pick.
  boot.blacklistedKernelModules = ["snd_soc_es8328" "snd_soc_es8328_i2c" "snd_soc_es8328_spi"];
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    # One sink that feeds both HDMI ports, so sound follows the picture
    #  whichever port the TV is plugged into.
    extraConfig.pipewire."60-hdmi-both" = {
      "context.modules" = [
        {
          name = "libpipewire-module-combine-stream";
          args = {
            "combine.mode" = "sink";
            "node.name" = "hdmi_both";
            "node.description" = "HDMI (both ports)";
            "combine.props" = {
              "audio.position" = ["FL" "FR"];
              "priority.session" = 3000;
              "priority.driver" = 3000;
            };
            "stream.rules" = [
              {
                matches = [
                  {
                    "media.class" = "Audio/Sink";
                    "node.name" = "~alsa_output.*";
                  }
                ];
                actions.create-stream = {};
              }
            ];
          };
        }
      ];
    };
  };

  # Never sleep; the TV is the power switch.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  environment.systemPackages = with pkgs; [
    v4l-utils # v4l2-ctl --list-devices, to check the hardware decoders
    libdrm # modetest
    pulseaudio # pactl, for checking sinks over ssh
    powertop
    nvtopPackages.panthor
  ];
}
