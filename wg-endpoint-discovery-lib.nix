# Shared WireGuard endpoint discovery logic
# Used by both Guardian machines and dev machines
{pkgs}: {
  # Generate the discovery script with configurable parameters
  makeDiscoveryScript = {
    interface,
    registryUrl,
    wgPort,
  }: let
    wg = "${pkgs.wireguard-tools}/bin/wg";
    curl = "${pkgs.curl}/bin/curl";
    ping = "${pkgs.iputils}/bin/ping";
    avahi = "${pkgs.avahi}/bin";
    netcat = "${pkgs.netcat}/bin/nc";
    awk = "${pkgs.gawk}/bin/awk";
    port = builtins.toString wgPort;
  in ''
    echo "Starting WireGuard endpoint discovery..."

    # Function to extract IP from endpoint (handles both IPv4 and IPv6 with brackets)
    extract_ip() {
      local endpoint=$1
      # IPv6: [fd42::1]:${port} -> fd42::1
      # IPv4: 1.2.3.4:${port} -> 1.2.3.4
      echo "$endpoint" | sed -E 's/\[(.+)\]:[0-9]+/\1/; s/([^:]+):[0-9]+$/\1/'
    }

    # Function to test if an endpoint is reachable
    test_endpoint() {
      local ip=$1
      timeout 2 ${netcat} -zu "$ip" "${port}" 2>/dev/null
    }

    while true; do
      # Fetch endpoint data from relay registry
      if ! REGISTRY_DATA=$(${curl} -sf --max-time 5 ${registryUrl} 2>/dev/null); then
        echo "Failed to reach registry, retrying in 30s..."
        sleep 30
        continue
      fi

      # Get our public key and endpoint from registry
      OUR_PUBKEY=$(${wg} show ${interface} public-key)
      OUR_ENDPOINT=$(echo "$REGISTRY_DATA" | tail -n +2 | while IFS=$'\t' read -r pubkey psk endpoint rest; do
        if [ "$pubkey" = "$OUR_PUBKEY" ]; then
          echo "$endpoint"
          break
        fi
      done || true)

      # Extract our public IP (without port) - handles both IPv4 and IPv6
      OUR_PUBLIC_IP=$(extract_ip "$OUR_ENDPOINT")

      # Parse dump output and update endpoints
      echo "$REGISTRY_DATA" | tail -n +2 | while IFS=$'\t' read -r pubkey psk endpoint allowed_ips handshake rx tx keepalive || [ -n "$pubkey" ]; do
        # Skip ourselves
        if [ "$pubkey" = "$OUR_PUBKEY" ]; then
          continue
        fi

        # Skip if no endpoint
        if [ -z "$endpoint" ] || [ "$endpoint" = "(none)" ]; then
          continue
        fi

        # Check if we have this peer
        if ! ${wg} show ${interface} peers | grep -q "$pubkey"; then
          continue
        fi

        # Extract peer's public IP and VPN IP - handles both IPv4 and IPv6
        PEER_PUBLIC_IP=$(extract_ip "$endpoint")
        PEER_VPN_IP=$(echo "$allowed_ips" | cut -d, -f1 | cut -d/ -f1)

        # Get relay's public IP from our own endpoint (we connect to relay)
        RELAY_PUBLIC_IP=$(extract_ip "$OUR_ENDPOINT")

        # Check for relay IP conflict:
        # If peer shares relay's public IP but we're on different network,
        # P2P requires port forwarding (skip unless configured)
        if [ "$PEER_PUBLIC_IP" = "$RELAY_PUBLIC_IP" ] && [ "$OUR_PUBLIC_IP" != "$RELAY_PUBLIC_IP" ]; then
          echo "Peer ''${pubkey:0:8}... shares relay's public IP, but we're remote - skipping P2P (would need port forwarding)"
          continue
        fi

        # Determine target endpoint
        TARGET_ENDPOINT="$endpoint"
        KEEPALIVE=25

        # If peer is on same LAN (same public IP), use routing-aware discovery
        if [ "$PEER_PUBLIC_IP" = "$OUR_PUBLIC_IP" ]; then
          echo "Peer ''${pubkey:0:8}... on same LAN, attempting routing-aware discovery..."

          # Try to resolve VPN IP to hostname via mDNS
          HOSTNAME=$(${avahi}/avahi-resolve-address "$PEER_VPN_IP" 2>/dev/null | ${awk} '{print $2}')

          if [ -n "$HOSTNAME" ]; then
            # Ensure hostname has .local suffix for mDNS
            case "$HOSTNAME" in
              *.local) ;;
              *) HOSTNAME="$HOSTNAME.local" ;;
            esac

            # Get peer's LAN IP - prefer IPv6, fallback to IPv4
            # Filter out link-local IPv6 addresses (fe80::) as they're not usable for WireGuard
            PEER_LAN_IP=$(${avahi}/avahi-resolve-host-name -6 "$HOSTNAME" 2>/dev/null | ${awk} '{print $2}')
            if [ -n "$PEER_LAN_IP" ] && echo "$PEER_LAN_IP" | grep -q "^fe80:"; then
              echo "  Skipping link-local IPv6 address $PEER_LAN_IP, trying IPv4..."
              PEER_LAN_IP=""
            fi
            if [ -z "$PEER_LAN_IP" ]; then
              PEER_LAN_IP=$(${avahi}/avahi-resolve-host-name -4 "$HOSTNAME" 2>/dev/null | ${awk} '{print $2}')
            fi

            if [ -n "$PEER_LAN_IP" ]; then
              # Ask kernel: which source IP would we use to reach this peer?
              # This respects routing metrics and ensures symmetric routing
              OUR_LAN_IP=$(ip route get "$PEER_LAN_IP" 2>/dev/null | grep -oP 'src \K\S+')

              if [ -n "$OUR_LAN_IP" ] && test_endpoint "$OUR_LAN_IP"; then
                echo "Found routing-aware LAN endpoint: $OUR_LAN_IP:${port} (to reach $PEER_LAN_IP)"
                TARGET_ENDPOINT="$OUR_LAN_IP:${port}"
                KEEPALIVE=0  # no keepAlive needed for LAN connection
              else
                echo "LAN routing check failed, skipping update to preserve static endpoint"
                continue
              fi
            else
              echo "Avahi hostname resolution failed, skipping update to preserve static endpoint"
              continue
            fi
          else
            echo "Avahi address resolution failed, skipping update to preserve static endpoint"
            continue
          fi
        fi

        # Get current endpoint
        CURRENT=$(${wg} show ${interface} peer "$pubkey" endpoint 2>/dev/null || echo "(none)")

        # Update if changed
        if [ "$CURRENT" != "$TARGET_ENDPOINT" ]; then
          echo "Updating peer ''${pubkey:0:8}...: $CURRENT -> $TARGET_ENDPOINT"

          # Set endpoint with appropriate keepalive based on protocol
          TARGET_IP=$(extract_ip "$TARGET_ENDPOINT")
          ${wg} set ${interface} peer "$pubkey" endpoint "$TARGET_ENDPOINT" persistent-keepalive $KEEPALIVE

          # Trigger connection with ping
          if [ -n "$PEER_VPN_IP" ]; then
            ${ping} -c 2 -W 1 "$PEER_VPN_IP" &>/dev/null &
          fi
        fi
      done

      sleep 30
    done
  '';
}
