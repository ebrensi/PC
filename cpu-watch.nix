# Warn about runaway processes when the fan isn't within earshot (e.g. over SSH).
# cpu-watch.py samples /proc and, when a process (or the whole system) stays
# hot for the full window, writes a banner that every new interactive shell
# prints. Raise/clear history: `journalctl -u cpu-watch`. It never kills anything.
{pkgs, ...}: let
  cpu-watch = pkgs.writers.writePython3Bin "cpu-watch" {flakeIgnore = ["E501" "W503"];} (builtins.readFile ./cpu-watch.py);
in {
  systemd.services.cpu-watch = {
    description = "Detect sustained runaway CPU usage";
    wantedBy = ["multi-user.target"];
    environment = {
      INTERVAL = "30"; # seconds between samples
      WINDOW = "600"; # must stay hot this long (seconds) before alerting
      PROC_PCT = "90"; # one process, % of a single core
      SYS_PCT = "40"; # all processes, % of all cores
      EXCLUDE_USER_PREFIXES = "nixbld"; # long nix builds are expected to be hot
    };
    serviceConfig = {
      ExecStart = "${cpu-watch}/bin/cpu-watch";
      Restart = "always";
      DynamicUser = true;
      RuntimeDirectory = "cpu-watch";
      RuntimeDirectoryMode = "0755";
      Nice = 19;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateNetwork = true;
      NoNewPrivileges = true;
    };
  };

  environment.interactiveShellInit = ''
    if [ -s /run/cpu-watch/alerts ]; then cat /run/cpu-watch/alerts; fi
  '';
}
