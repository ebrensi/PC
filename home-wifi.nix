# This module configures my home wifi and prioritizes it over wired ethernet
{
  pkgs,
  lib,
  ...
}: {
  networking.wireless = {
    enable = true;
    userControlled.enable = true;
    networks.CiscoKid = {
      ssid = "CiscoKid";
      psk = "8c1b86a16eecd3996e724f7e21ff1818b03c8c463457fc9a3901c5ef7bc14d55";
    };
  };
  networking.networkmanager = {
    enable = true;
    wifi.powersave = true;
    settings = {
      # Prefer wifi over wired ethernet when both are available
      # since wired connection is a relatively slow Powerline connection
      connection-wifi = {
        match-device = "type:wifi";
        "ipv4.route-metric" = 0;
        "ipv6.route-metric" = 0;
      };
    };
  };
}
