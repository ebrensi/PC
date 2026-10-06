# TV appliance profile: Kodi fullscreen on the HDMI output, no desktop.
#
# Kodi draws straight to the display through DRM/GBM (no compositor), which is
#  what lets it switch refresh rates to match the video and hand decoded frames
#  to the display controller without copying them.
#
# Media comes from the Jellyfin server on adder-ws via the JellyCon add-on;
#  phones and laptops can push to Kodi over UPnP/DLNA, the Kodi web remote, or
#  the "Send to Kodi" browser/phone share target.
{
  config,
  lib,
  pkgs,
  ...
}: let
  user = "efrem";
  public-keys = import ./secrets/public-keys.nix;

  kodi = pkgs.kodi-gbm.withPackages (k:
    with k; [
      jellycon # Jellyfin client that browses the server live (no local library sync)
      youtube # needs your own YouTube API keys; see the add-on's setup wizard
      sendtokodi # play links shared from a phone/browser
      sponsorblock
    ]);
in {
  # Admin account. This box deliberately skips user-efrem.nix: a TV has no use
  #  for the dev repos it clones or the AWS/Guardian credentials it decrypts.
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = ["wheel" "video" "audio"];
    initialPassword = "password";
    openssh.authorizedKeys.keys = with public-keys; [personal-ssh-key phone];
  };
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [user]; # so deploy-binaries can copy closures in

  # Kodi runs as its own unprivileged user, owning tty1 the way a display
  #  manager would. Its settings and add-on data live in /var/lib/kodi/.kodi.
  users.users.kodi = {
    isSystemUser = true;
    group = "kodi";
    home = "/var/lib/kodi";
    createHome = true;
    extraGroups = ["video" "render" "input" "audio"];
  };
  users.groups.kodi = {};

  systemd.services.kodi = {
    description = "Kodi media center";
    after = ["systemd-user-sessions.service" "network-online.target" "sound.target"];
    wants = ["network-online.target"];
    conflicts = ["getty@tty1.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      User = "kodi";
      # A PAM login session on tty1 gives Kodi a logind seat, so it can
      #  become DRM master and open input devices.
      PAMName = "login";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
      StandardInput = "tty";
      StandardOutput = "journal";
      ExecStart = "${kodi}/bin/kodi-standalone";
      Restart = "always";
      RestartSec = 2;
    };
  };

  # HDMI-CEC: lets the TV's own remote drive Kodi (libcec uses /dev/cec0).
  services.udev.extraRules = ''
    KERNEL=="cec[0-9]*", GROUP="video", MODE="0660"
  '';

  # Kodi talks to ALSA directly, which is what makes HDMI audio passthrough
  #  (Dolby/DTS to a receiver) work; a sound server would sit in the way.
  services.pipewire.enable = lib.mkForce false;

  # Never sleep; the TV is the power switch.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Ports for services enabled in Kodi's own settings (Settings > Services).
  #  mDNS (5353) is already open via avahi in base.nix.
  networking.firewall = {
    allowedTCPPorts = [
      8080 # web interface + HTTP JSON-RPC (Kore/Yatse remotes)
      9090 # JSON-RPC over WebSocket (remote apps' live updates)
    ];
    allowedUDPPorts = [
      1900 # UPnP/SSDP discovery, so phones see Kodi as a cast target
      9777 # EventServer (remote apps' button presses)
    ];
  };

  environment.systemPackages = [
    kodi # kodi-send etc. for scripting over ssh
    pkgs.libcec # cec-client, for debugging the TV remote
    pkgs.v4l-utils # v4l2-ctl --list-devices, to check the hardware decoders
    pkgs.libdrm # modetest
  ];
}
