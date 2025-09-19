{
  pkgs,
  lib,
  ...
}: {
  # Cosmic desktop
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

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

  # We have to disable this ssh agent because it conflicts with the one that Cosmic starts
  programs.ssh.startAgent = lib.mkForce true;
  services.gnome.gcr-ssh-agent.enable = lib.mkForce false;
}
