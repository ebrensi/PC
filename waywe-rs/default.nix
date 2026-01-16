# Example NixOS module for waywe-rs
# Save this as waywe-module.nix in your NixOS config directory
{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.waywe-rs;
in {
  options.services.waywe-rs.enable = lib.mkEnableOption ''
    Enable Wayland Wallpaper Engine service
  '';

  config = lib.mkIf cfg.enable {
    # Install waywe-rs package
    environment.systemPackages = [
      (pkgs.callPackage ./waywe-rs.nix {})
    ];

    # Optional: Create a systemd user service to auto-start the daemon
    # This will start waywe-daemon when you log in
    systemd.user.services.waywe-daemon = {
      description = "Waywe Wayland Wallpaper Daemon";
      wantedBy = ["cosmic-session.target"];
      after = ["cosmic-session.target"];
      partOf = ["cosmic-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.callPackage ./waywe-rs.nix {}}/bin/waywe-daemon";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # Ensure required environment variables are set
    environment.sessionVariables = {
      # Help waywe find VA-API drivers
      LIBVA_DRIVER_NAME = lib.mkDefault "iHD"; # For Intel iGPU, change to "Gallium" for AMD
    };

    # Optional: Create a default config file
    # This will be placed in ~/.config/waywe/config.toml
    environment.etc."waywe/config.toml.example".text = ''
      [animation]
      duration-milliseconds = 2000
      direction = "out"
      easing = "ease-out"

      [animation.center-position]
      type = "random"
      position = [0.0, 0.0]

      [[effects]]
      type = "blur"
      n_levels = 4
      level_multiplier = 2
    '';
  };
}
