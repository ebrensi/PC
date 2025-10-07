# This module configures my home wifi and prioritizes it over wired ethernet
{
  pkgs,
  lib,
  ...
}: {
  networking.networkmanager = {
    enable = true;
    wifi.powersave = true;

    # Define the wifi connection
    ensureProfiles = {
      environmentFiles = [
        (pkgs.writeText "nm-home-wifi.env" ''
          WIFI_PSK=8c1b86a16eecd3996e724f7e21ff1818b03c8c463457fc9a3901c5ef7bc14d55
        '')
      ];
      profiles = {
        CiscoKid = {
          connection = {
            id = "CiscoKid";
            type = "wifi";
            autoconnect = true;
          };
          wifi = {
            ssid = "CiscoKid";
            mode = "infrastructure";
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk = "$WIFI_PSK";
          };
          ipv4 = {
            method = "auto";
            route-metric = 0;
          };
          ipv6 = {
            method = "auto";
            route-metric = 0;
          };
        };
      };
    };

    # # Set higher metrics for wired connections
    # settings = {
    #   # Prefer wifi over wired ethernet when both are available
    #   # since wired connection is a relatively slow Powerline connection
    #   connection-wifi = {
    #     match-device = "type:wifi";
    #     "ipv4.route-metric" = 0;
    #     "ipv6.route-metric" = 0;
    #   };
    # };
  };
}
