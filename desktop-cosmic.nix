{
  pkgs,
  lib,
  ...
}: {
  boot.kernelParams = ["nvidia_drm.fbdev=1"];

  services = {
    # Cosmic desktop
    desktopManager.cosmic.enable = true;
    displayManager.cosmic-greeter.enable = true;
    system76-scheduler.enable = true;

    # Secret Service provider (libsecret). SSH is handled by programs.ssh.startAgent;
    # gnome-keyring >= 46 no longer ships its own ssh component, so no conflict.
    gnome.gnome-keyring.enable = lib.mkForce true;
    gnome.gcr-ssh-agent.enable = lib.mkForce false;
  };

  environment.sessionVariables = {
    COSMIC_DATA_CONTROL_ENABLED = "1";
    NIXOS_OZONE_WL = "1";
  };

  programs = {
    # Use systemd SSH agent (reliable and simple)
    ssh.startAgent = lib.mkForce true;

    # Provides NM secret agent needed for GUI-based WiFi credential entry
    nm-applet.enable = true;
  };

  # We will use this until Cosmic's firmware update works
  environment.systemPackages = with pkgs; [
    cosmic-wallpapers
  ];
}
