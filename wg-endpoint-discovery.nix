# WireGuard Endpoint Discovery for dev machines
# Queries the relay registry and updates peer endpoints for NAT hole punching
{
  config,
  pkgs,
  ...
}: let
  wg-port = "51820";
  endpoint-registry-url = "http://12.167.1.1:8888";
  discoveryLib = import ./wg-endpoint-discovery-lib.nix {inherit pkgs;};
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

    script = discoveryLib.makeDiscoveryScript {
      interface = "wghome";
      registryUrl = endpoint-registry-url;
      wgPort = wg-port;
    };
  };
}
