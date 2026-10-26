# TV appliance profile: a cast target, not a media center.
#
# The screen sits on YouTube's TV interface (youtube.com/tv) in a fullscreen
#  browser. Nothing is browsed on the TV itself; phones push to it from the
#  YouTube app: Cast > "Link with TV code" (code from the TV's Settings page).
#  Desktop Chrome finds it on the LAN via DIAL (tv-dial.py), like a smart TV.
#  tv-dial also shows any web page on request. This bookmarklet sends the
#  current page, and /go?url=home returns to YouTube:
#    javascript:open('http://tv.local:56790/go?url='+encodeURIComponent(location.href),'_','width=300,height=80')
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

  # Caps YouTube at 1080p, the TV's resolution. With the Cobalt user agent,
  #  YouTube picks its stream by asking Cobalt-style
  #  `isTypeSupported('video/webm; codecs="vp9"; width=3840; height=2160')`.
  #  Chromium ignores the size, says yes, and plays 4K, which it decodes in
  #  software (~3 cores, enough to trip tv-status's load warning).
  maxResManifest = pkgs.writeText "manifest.json" (builtins.toJSON {
    manifest_version = 3;
    name = "Cap video at 1080p";
    version = "1";
    content_scripts = [
      {
        matches = ["https://www.youtube.com/*"];
        js = ["cap.js"];
        run_at = "document_start";
        world = "MAIN";
        all_frames = true;
      }
    ];
  });
  maxResScript = pkgs.writeText "cap.js" ''
    (() => {
      const tooBig = (w, h) => w > 1920 || h > 1080;
      const param = (type, name) => Number((type.match(new RegExp(name + "=(\\d+)")) || [])[1] || 0);
      const orig = MediaSource.isTypeSupported.bind(MediaSource);
      MediaSource.isTypeSupported = (type) =>
        !tooBig(param(type, "width"), param(type, "height")) && orig(type);
      if (navigator.mediaCapabilities) {
        const decodingInfo = navigator.mediaCapabilities.decodingInfo.bind(navigator.mediaCapabilities);
        navigator.mediaCapabilities.decodingInfo = (config) => {
          const v = config && config.video;
          if (v && tooBig(v.width, v.height)) {
            return Promise.resolve({supported: false, smooth: false, powerEfficient: false});
          }
          return decodingInfo(config);
        };
      }
    })();
  '';
  # Real files, not symlinks: Chromium won't inject a content script whose
  #  file resolves outside the extension's directory.
  maxResExtension = pkgs.runCommand "tv-max-res-extension" {} ''
    mkdir $out
    cp ${maxResManifest} $out/manifest.json
    cp ${maxResScript} $out/cap.js
  '';

  browser = lib.escapeShellArgs [
    (lib.getExe pkgs.chromium)
    "--kiosk"
    "--load-extension=${maxResExtension}"
    # Chromium ignores --load-extension (silently) unless this is turned off.
    "--disable-features=DisableLoadExtensionCommandLineSwitch"
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

  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  wtype = lib.getExe pkgs.wtype;

  # `tv-status toggle` shows a status overlay (a persistent mako notification,
  #  redrawn every couple of seconds) above whatever the kiosk is showing.
  #  `tv-status watch` pops the same overlay up for a few seconds, at most once
  #  every ten minutes, when something looks wrong. Rows past their threshold
  #  are marked red with a "!".
  tv-status = pkgs.writeShellApplication {
    name = "tv-status";
    runtimeInputs = with pkgs; [procps util-linux gawk iproute2 curl jq mako libnotify wireplumber];
    text = ''
      runtime=/run/user/$(id -u)
      export DBUS_SESSION_BUS_ADDRESS=unix:path=$runtime/bus
      popupfile=$runtime/tv-status.popup

      # Thresholds. Disk only marks the overlay; it never pops it up.
      max_temp=75     # °C
      min_wifi=40     # % link quality
      min_mem=2048    # MB available
      max_load5=6     # 5-minute load average, on 8 cores
      max_disk=85     # % used

      collect() {
        temp=$(awk '{ if ($1 > m) m = $1 } END { printf "%.0f", m / 1000 }' /sys/class/thermal/thermal_zone*/temp)
        wifi=$(awk 'NR == 3 { printf "%d", $3 * 100 / 70 }' /proc/net/wireless)
        mem=$(awk '/^MemAvailable/ { printf "%d", $2 / 1024 }' /proc/meminfo)
        swap=$(awk '/^SwapTotal/ { t = $2 } /^SwapFree/ { f = $2 } END { printf "%d", (t - f) / 1024 }' /proc/meminfo)
        load=$(cut -d' ' -f1-3 /proc/loadavg)
        load5=$(cut -d' ' -f2 /proc/loadavg)
        disk=$(df --output=pcent / | tail -n 1 | tr -dc 0-9)
        if tabs=$(curl -sf --max-time 2 http://127.0.0.1:${toString cdpPort}/json/list); then
          page=$(echo "$tabs" | jq -r '[.[] | select(.type == "page")][0].url // "?"' | cut -c1-70)
          bad_browser=0
        else
          page="not responding"
          bad_browser=1
        fi

        wifi_text=none
        if [ -n "$wifi" ]; then wifi_text="$wifi%"; fi
        bad_temp=$((temp >= max_temp ? 1 : 0))
        bad_wifi=0
        if [ -n "$wifi" ] && [ "$wifi" -lt "$min_wifi" ]; then bad_wifi=1; fi
        bad_mem=$((mem < min_mem ? 1 : 0))
        bad_swap=$((swap > 0 ? 1 : 0))
        bad_load=$(awk -v l="$load5" -v m="$max_load5" 'BEGIN { print (l > m) ? 1 : 0 }')
        bad_disk=$((disk >= max_disk ? 1 : 0))
      }

      # row LABEL TEXT BAD
      row() {
        text=$(echo "$2" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        if [ "$3" = 1 ]; then
          printf '<span foreground="#ff5555">! %-8s %s</span>\n' "$1" "$text"
        else
          printf '  %-8s %s\n' "$1" "$text"
        fi
      }

      render() {
        row Address "$(ip -4 -br addr show scope global | awk '{ printf "%s  ", $3 }')" 0
        row WiFi "$wifi_text" "$bad_wifi"
        row Uptime "$(uptime -p | sed 's/^up //')" 0
        row Load "$load" "$bad_load"
        row Temp "$temp°C" "$bad_temp"
        row Memory "$mem MB free, swap used $swap MB" $((bad_mem + bad_swap > 0 ? 1 : 0))
        row Disk "$disk% used" "$bad_disk"
        row Volume "$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | sed 's/Volume: //')" 0
        row Showing "$page" "$bad_browser"
      }

      notify() {
        notify-send -t 0 -h string:x-canonical-private-synchronous:tv-status "$1" "$(render)"
      }

      # Whether a status loop is running (no pidfile: a double press could race it).
      overlay_on() {
        pgrep -u "$(id -u)" -f "tv-status loop" >/dev/null
      }

      loop() {
        while true; do
          collect
          notify "TV status"
          sleep 2
        done
      }

      watch() {
        last=0
        sleep 90
        while true; do
          collect
          now=$(date +%s)
          if [ $((bad_temp + bad_wifi + bad_mem + bad_swap + bad_load + bad_browser)) -gt 0 ] &&
            [ $((now - last)) -ge 600 ] && ! overlay_on; then
            last=$now
            touch "$popupfile"
            notify "TV warning"
            sleep 10
            # A button press during the popup has already dismissed it.
            if [ -f "$popupfile" ]; then
              rm -f "$popupfile"
              makoctl dismiss -a
            fi
          fi
          sleep 30
        done
      }

      toggle() {
        # The ring can report a press twice, or both lower buttons at once:
        #  serialize, and ignore a press right after the last one.
        exec 9>"$runtime/tv-status.lock"
        flock 9
        now=$(date +%s%N)
        last=$(cat "$runtime/tv-status.last" 2>/dev/null || echo 0)
        echo "$now" > "$runtime/tv-status.last"
        if [ $(((now - last) / 1000000)) -lt 700 ]; then
          return
        fi
        if [ -f "$popupfile" ]; then
          rm -f "$popupfile"
          makoctl dismiss -a
        elif overlay_on; then
          pkill -u "$(id -u)" -f "tv-status loop" || true
          sleep 0.3 # let an in-flight notification land before dismissing
          makoctl dismiss -a
        else
          setsid "$0" loop 9>&- &
        fi
      }

      case "''${1:-toggle}" in
        loop) loop ;;
        watch) watch ;;
        toggle) toggle ;;
      esac
    '';
  };
  makoConfig = pkgs.writeText "tv-mako.conf" ''
    layer=overlay
    anchor=top-right
    margin=40
    padding=24
    width=900
    height=420
    font=monospace 22
    markup=1
    background-color=#000000d9
    text-color=#ffffff
    border-size=0
    default-timeout=0
  '';

  swayConfig = pkgs.writeText "tv-sway.conf" ''
    output * bg #000000 solid_color
    default_border none
    seat * hide_cursor 3000
    # Volume keys, as sent by the Bluetooth volume knob (and any remote). The
    #  default sink is the combined HDMI one, so this follows the picture.
    bindsym --locked XF86AudioRaiseVolume exec ${wpctl} set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
    bindsym --locked XF86AudioLowerVolume exec ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindsym --locked XF86AudioMute exec ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle
    # The finger-ring trackball sends right-click for its lower two buttons and
    #  wheel ticks for its wheel. The lower buttons (indistinguishable) toggle
    #  the status overlay; Back is on one of its upper buttons. YouTube TV
    #  navigates by key only, so the wheel becomes Up/Down.
    bindsym --whole-window button3 exec ${lib.getExe tv-status} toggle
    bindsym --whole-window button4 exec ${wtype} -k Up
    bindsym --whole-window button5 exec ${wtype} -k Down
    exec ${lib.getExe pkgs.mako} --config ${makoConfig}
    exec ${lib.getExe tv-status} watch
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
  nix.settings.trusted-users = [user]; # so deploy can copy closures in

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
  # Parks the kiosk tab on a black page while the TV is off (HDMI-CEC), so
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

  # Home WiFi, in place of the slower powerline ethernet. NetworkManager runs
  #  on the iwd backend and can't hand iwd a PSK, so iwd needs its own network
  #  file; it then auto-connects and NetworkManager adopts the link (DHCP).
  #  The key is the hashed form (same as the installer's pskRaw), not the
  #  passphrase.
  systemd.tmpfiles.rules = [
    "f+ /var/lib/iwd/CiscoKid.psk 0600 root root - [Security]\\nPreSharedKey=8c1b86a16eecd3996e724f7e21ff1818b03c8c463457fc9a3901c5ef7bc14d55\\n"
  ];

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

  environment.systemPackages = with pkgs; let
    dev-scripts = import ./dev-scripts.nix {inherit pkgs;};
  in [
    v4l-utils # v4l2-ctl --list-devices, to check the hardware decoders
    libdrm # modetest
    pulseaudio # pactl, for checking sinks over ssh
    powertop
    nvtopPackages.panthor
    dev-scripts.tmx
  ];
}
