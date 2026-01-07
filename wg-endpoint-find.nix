{
  config,
  pkgs,
  lib,
  ...
}: let
  interface = "wghome";
in {
  # Systemd service to probe peer endpoints
  systemd.services.wireguard-endpoint-probe = {
    description = "Probe WireGuard peers for direct connectivity";
    after = ["wireguard-${interface}.service" "network-online.target"];
    wants = ["wireguard-${interface}.service" "network-online.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      # Run as root to read WireGuard config
      User = "root";
    };

    script = ''
      # Wait for WireGuard interface to be fully configured
      for i in {1..10}; do
        if ${pkgs.iproute2}/bin/ip link show ${interface} &>/dev/null; then
          break
        fi
        sleep 1
      done

      # Extract peer VPN IPs from WireGuard configuration
      # This gets the allowed-ips for each peer (excluding /0 routes)
      PEER_IPS=$(${pkgs.wireguard-tools}/bin/wg show ${interface} allowed-ips | \
                 ${pkgs.gawk}/bin/awk '{print $2}' | \
                 ${pkgs.gnugrep}/bin/grep -v '/0$' | \
                 ${pkgs.coreutils}/bin/cut -d/ -f1 | \
                 ${pkgs.coreutils}/bin/sort -u)

      if [ -z "$PEER_IPS" ]; then
        echo "No WireGuard peers found to probe"
        exit 0
      fi

      echo "Probing WireGuard peers for endpoint discovery..."

      # Ping each peer to trigger endpoint learning
      # -c 2: Send 2 packets (increases chance of discovery)
      # -W 1: Wait max 1 second for response
      # -i 0.2: 200ms interval between packets
      for ip in $PEER_IPS; do
        echo "Probing $ip..."
        ${pkgs.iputils}/bin/ping -c 2 -W 1 -i 0.2 "$ip" &>/dev/null &
      done

      # Wait for all pings to complete
      wait

      # Show discovered endpoints
      echo "Current WireGuard endpoints:"
      ${pkgs.wireguard-tools}/bin/wg show ${interface} endpoints
    '';
  };

  # Timer to run probing on boot and periodically
  systemd.timers.wireguard-endpoint-probe = {
    description = "Periodic WireGuard endpoint probing";
    wantedBy = ["timers.target"];

    timerConfig = {
      # Probe shortly after boot (after WireGuard is up)
      OnBootSec = "30s";

      # Re-probe every 5 minutes to handle:
      # - IP changes (roaming devices)
      # - New peers coming online
      # - Endpoint changes after network issues
      OnUnitActiveSec = "5min";

      # Add randomization to avoid thundering herd
      RandomizedDelaySec = "30s";

      # Don't accumulate if system is suspended
      Persistent = false;
    };
  };

  # Helper script for manual endpoint discovery
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "wg-discover" ''
      echo "Triggering WireGuard endpoint discovery..."
      sudo systemctl start wireguard-endpoint-probe.service

      echo ""
      echo "Waiting for probes to complete..."
      sleep 3

      echo ""
      echo "Current endpoints:"
      sudo wg show ${interface} endpoints

      echo ""
      echo "Recent handshakes:"
      sudo wg show ${interface} latest-handshakes
    '')
  ];

  # Add helpful alias
  environment.shellAliases = {
    wg-probe = "sudo systemctl start wireguard-endpoint-probe.service";
  };
}
