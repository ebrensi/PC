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
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable wireguard interface";
    };
    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 51820;
      description = "UDP port for WireGuard to listen on";
    };
    interface = lib.mkOption {
      type = lib.types.str;
      description = "WireGuard VPN interface name";
      default = "wg-home";
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
    cidr = lib.mkOption {
      type = lib.types.str;
      description = "WireGuard VPN CIDR";
      default = "fd00::/120"; # gives us fd00::1 to fd00::ff
    };
    prefix = lib.mkOption {
      type = lib.types.str;
      description = "WireGuard VPN Prefix";
      default = builtins.elemAt (lib.splitString "/" cfg.cidr) 0;
      internal = true;
      readOnly = true;
    };
    peers = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      description = "";
      default = [];
    };
    endpoint-registry-url = lib.mkOption {
      type = lib.types.str;
      description = "";
      default = "http://[${cfg.prefix}1]:8888";
    };
    endpoint-discovery = lib.mkEnableOption ''
      Enable Endpoint Discovery Service to facilitate P2P connections
    '';
  };

  config = lib.mkIf cfg.enable {
    networking.wireguard.interfaces.${cfg.interface} = {inherit (cfg) ips listenPort privateKeyFile peers;};

    networking.firewall = {
      allowedUDPPorts = [cfg.listenPort];
      trustedInterfaces = ["${cfg.interface}"];
      checkReversePath = false;
    };
  };
}
