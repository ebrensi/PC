{
  config,
  lib,
  pkgs,
  ...
}: {
  hardware = {
    system76.enableAll = true;
  };

  environment.systemPackages = [
    pkgs.system76-firmware
    pkgs.system76-power
    pkgs.system76-keyboard-configurator
  ];

  # see https://support.system76.com/articles/system76-software/
  services.power-profiles-daemon.enable = false;

  # boot = {
  #   # System76 specific kernel parameters
  #   kernelParams = [
  #     "ec_sys.write_support=1" # Required for System76 hardware support
  #   ];

  #   # Enable firmware updates
  #   kernelModules = ["system76_acpi"];
  # };
}
