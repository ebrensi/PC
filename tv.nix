# TV appliance profile: a cast target, not a media center.
#
# The screen sits on YouTube's TV interface (youtube.com/tv) in a fullscreen
#  browser. Nothing is browsed on the TV itself; phones push to it from the
#  YouTube app: Cast > "Link with TV code" (code from the TV's Settings page).
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

  browser = lib.escapeShellArgs [
    (lib.getExe pkgs.chromium)
    "--kiosk"
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
  ];
}
