# WireGuard Endpoint Discovery for dev machines
# Queries the relay registry and updates peer endpoints for NAT hole punching
{
  config,
  pkgs,
  ...
}: let
  wg-port = "51820";
  endpoint-registry-url = "http://12.167.1.1:8888";
in {
  systemd.services.wireguard-endpoint-discovery = {
    description = "WireGuard Endpoint Discovery Client";
    after = ["wg-quick-wghome.service" "network-online.target"];
    wants = ["wg-quick-wghome.service" "network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "30s";
      User = "root";
    };
    script = let
      wg = "${pkgs.wireguard-tools}/bin/wg";
      curl = "${pkgs.curl}/bin/curl";
      ping = "${pkgs.iputils}/bin/ping";
      avahi = "${pkgs.avahi}/bin";
      netcat = "${pkgs.netcat}/bin/nc";
    in ''
      echo "Starting WireGuard endpoint discovery..."

      # Function to test if an endpoint is reachable
      test_endpoint() {
        local ip=$1
        local port=${wg-port}
        timeout 2 ${netcat} -zu "$ip" "$port" 2>/dev/null
      }

      while true; do
        # Fetch endpoint data from relay registry
        if ! REGISTRY_DATA=$(${curl} -sf --max-time 5 ${endpoint-registry-url} 2>/dev/null); then
          echo "Failed to reach registry, retrying in 30s..."
          sleep 30
          continue
        fi

        # Get our public key and endpoint from registry
        OUR_PUBKEY=$(${wg} show wghome public-key)
        OUR_ENDPOINT=$(echo "$REGISTRY_DATA" | tail -n +2 | while IFS=$'\t' read -r pubkey psk endpoint rest; do
          if [ "$pubkey" = "$OUR_PUBKEY" ]; then
            echo "$endpoint"
            break
          fi
        done)

        # Extract our public IP (without port)
        OUR_PUBLIC_IP=$(echo "$OUR_ENDPOINT" | cut -d: -f1)

        # Parse dump output and update endpoints
        echo "$REGISTRY_DATA" | tail -n +2 | while IFS=$'\t' read -r pubkey psk endpoint allowed_ips handshake rx tx keepalive; do
          # Skip ourselves
          if [ "$pubkey" = "$OUR_PUBKEY" ]; then
            continue
          fi

          # Skip if no endpoint
          if [ -z "$endpoint" ] || [ "$endpoint" = "(none)" ]; then
            continue
          fi

          # Check if we have this peer
          if ! ${wg} show wghome peers | grep -q "$pubkey"; then
            continue
          fi

          # Extract peer's public IP and VPN IP
          PEER_PUBLIC_IP=$(echo "$endpoint" | cut -d: -f1)
          PEER_VPN_IP=$(echo "$allowed_ips" | cut -d, -f1 | cut -d/ -f1)

          # Determine target endpoint
          TARGET_ENDPOINT="$endpoint"

          # If peer is on same LAN (same public IP), try to discover LAN endpoint via Avahi
          if [ "$PEER_PUBLIC_IP" = "$OUR_PUBLIC_IP" ]; then
            echo "Peer ''${pubkey:0:8}... on same LAN, attempting Avahi discovery..."

            # Try to resolve VPN IP to hostname via mDNS
            HOSTNAME=$(${avahi}/avahi-resolve-address "$PEER_VPN_IP" 2>/dev/null | awk '{print $2}')

            if [ -n "$HOSTNAME" ]; then
              # Ensure hostname has .local suffix for mDNS
              [[ "$HOSTNAME" != *.local ]] && HOSTNAME="$HOSTNAME.local"

              # Resolve hostname to LAN IP
              LAN_IP=$(${avahi}/avahi-resolve-host-name -4 "$HOSTNAME" 2>/dev/null | awk '{print $2}')

              if [ -n "$LAN_IP" ] && test_endpoint "$LAN_IP"; then
                echo "Found LAN endpoint: $LAN_IP:${wg-port}"
                TARGET_ENDPOINT="$LAN_IP:${wg-port}"
              else
                echo "LAN IP not reachable, skipping update to preserve static endpoint"
                continue
              fi
            else
              echo "Avahi resolution failed, skipping update to preserve static endpoint"
              continue
            fi
          fi

          # Get current endpoint
          CURRENT=$(${wg} show wghome peer "$pubkey" endpoint 2>/dev/null || echo "(none)")

          # Update if changed
          if [ "$CURRENT" != "$TARGET_ENDPOINT" ]; then
            echo "Updating peer ''${pubkey:0:8}...: $CURRENT -> $TARGET_ENDPOINT"
            ${wg} set wghome peer "$pubkey" endpoint "$TARGET_ENDPOINT"

            # Trigger connection with ping
            if [ -n "$PEER_VPN_IP" ]; then
              ${ping} -c 2 -W 1 "$PEER_VPN_IP" &>/dev/null &
            fi
          fi
        done

        sleep 30
      done
    '';
  };
}
