{
  pkgs,
  lib,
  ...
}: {
  # Cosmic desktop
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;
  services.system76-scheduler.enable = true;

  environment.sessionVariables = {
    COSMIC_DATA_CONTROL_ENABLED = "1";
    NIXOS_OZONE_WL = "1";
  };

  boot.kernelParams = ["nvidia_drm.fbdev=1"];

  # Use systemd SSH agent (reliable and simple)
  programs.ssh.startAgent = lib.mkForce true;
  services.gnome.gcr-ssh-agent.enable = lib.mkForce false;
  # Secret Service provider (libsecret). SSH is handled by programs.ssh.startAgent;
  # gnome-keyring >= 46 no longer ships its own ssh component, so no conflict.
  services.gnome.gnome-keyring.enable = lib.mkForce true;

  # Provides NM secret agent needed for GUI-based WiFi credential entry
  programs.nm-applet.enable = true;

  # We will use this until Cosmic's firmware update works
  environment.systemPackages = with pkgs; [
    cosmic-wallpapers
  ];
}
