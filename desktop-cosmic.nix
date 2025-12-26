{
  pkgs,
  lib,
  ...
}: {
  # Cosmic desktop
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;
  services.system76-scheduler.enable = true;

  # cosmic doesn't have good bluetooth support yet, so use blueman for now
  services.blueman.enable = true;

  environment.sessionVariables = {
    COSMIC_DATA_CONTROL_ENABLED = "1";
    NIXOS_OZONE_WL = "1";
  };

  boot.kernelParams = ["nvidia_drm.fbdev=1"];

  # prevent system from auto-sleeping
  # systemd.targets.sleep.enable = false;
  # systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Use systemd SSH agent (reliable and simple)
  programs.ssh.startAgent = lib.mkForce true;
  services.gnome.gcr-ssh-agent.enable = lib.mkForce false;
  services.gnome.gnome-keyring.enable = lib.mkForce false;

  # We will use this until Cosmic's firmware update works
  environment.systemPackages = with pkgs; [
    cosmic-wallpapers
    firmware-updater
  ];
}
