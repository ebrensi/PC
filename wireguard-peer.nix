# WireGuard Endpoint Discovery for dev machines
# Queries the relay registry and updates peer endpoints for NAT hole punching
{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.wireguard-peer;
in {
  options.wireguard-peer = {
    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 51820;
      description = "UDP port for WireGuard to listen on";
    };
    interface = lib.mkOption {
      type = lib.types.str;
      description = "WireGuard VPN interface name";
      default = "wghome";
    };
    ips = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "";
      default = [];
    };
    privateKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "";
    };
    peers = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      description = "";
      default = [];
    };
    endpoint-registry-url = lib.mkOption {
      type = lib.types.str;
      description = "";
      default = "http://[fd42::1]:8888";
    };
    endpoint-discovery = lib.mkEnableOption ''
      Enable Endpoint Discovery for P2P connections
    '';
  };

  config = {
    networking.wireguard.interfaces.${cfg.interface} = {inherit (cfg) ips listenPort privateKeyFile peers;};

    systemd.services.wireguard-endpoint-discovery = lib.mkIf cfg.endpoint-discovery {
      description = "WireGuard Endpoint Discovery Client";
      after = ["wg-quick-${cfg.interface}.service" "network-online.target"];
      wants = ["wg-quick-${cfg.interface}.service" "network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "30s";
        User = "root";
      };

      script = let
        discoveryLib = import ./wg-endpoint-discovery-lib.nix {inherit pkgs;};
      in
        discoveryLib.makeDiscoveryScript {
          interface = cfg.interface;
          registryUrl = cfg.endpoint-registry-url;
          wgPort = builtins.toString cfg.listenPort;
        };
    };

    # Fix IPv6 route metrics to prioritize WireGuard over RA routes
    systemd.services."wireguard-${cfg.interface}-fix-routes" = {
      description = "Fix WireGuard IPv6 route metrics";
      after = ["wireguard-${cfg.interface}.service"];
      wants = ["wireguard-${cfg.interface}.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        # Wait for WireGuard to create its routes
        sleep 2

        # Fix route metrics for all IPv6 routes on ${cfg.interface} interface
        ${pkgs.iproute2}/bin/ip -6 route show dev ${cfg.interface} | while read route; do
          dest=$(echo "$route" | ${pkgs.gawk}/bin/awk '{print $1}')
          ${pkgs.iproute2}/bin/ip -6 route del "$dest" dev ${cfg.interface} 2>/dev/null || true
          ${pkgs.iproute2}/bin/ip -6 route add "$dest" dev ${cfg.interface} metric 50
        done
      '';
    };

    networking.firewall = {
      allowedUDPPorts = [cfg.listenPort];
      trustedInterfaces = ["${cfg.interface}"];
      checkReversePath = false;
    };

    # Disable NixOS-managed /etc/hosts to allow manual modification
    # Base content will be created by activation script instead
    environment.etc.hosts.enable = false;
    systemd.tmpfiles.rules = [
      "R /etc/hosts"
      "C /etc/hosts 644 efrem users - ${config.environment.etc.hosts.source}"
    ];
  };
}
