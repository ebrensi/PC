# WireGuard Endpoint Discovery for dev machines
# Queries the relay registry and updates peer endpoints for NAT hole punching
{
  config,
  pkgs,
  ...
}: {
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
    in ''
      echo "Starting WireGuard endpoint discovery..."

      while true; do
        # Fetch endpoint data from relay registry
        if ! REGISTRY_DATA=$(${curl} -sf --max-time 5 http://12.167.1.1:8888 2>/dev/null); then
          echo "Failed to reach registry, retrying in 30s..."
          sleep 30
          continue
        fi

        # Get our public key
        OUR_PUBKEY=$(${wg} show wghome public-key)

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

          # Get current endpoint
          CURRENT=$(${wg} show wghome peer "$pubkey" endpoint 2>/dev/null || echo "(none)")

          # Update if changed
          if [ "$CURRENT" != "$endpoint" ]; then
            echo "Updating peer ''${pubkey:0:8}...: $CURRENT -> $endpoint"
            ${wg} set wghome peer "$pubkey" endpoint "$endpoint"

            # Trigger NAT hole punching with ping
            PEER_IP=$(echo "$allowed_ips" | cut -d, -f1 | cut -d/ -f1)
            if [ -n "$PEER_IP" ]; then
              ${ping} -c 2 -W 1 "$PEER_IP" &>/dev/null &
            fi
          fi
        done

        sleep 30
      done
    '';
  };
}
