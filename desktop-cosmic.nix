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
  services.gnome.gnome-keyring.enable = lib.mkForce false;

  # We will use this until Cosmic's firmware update works
  environment.systemPackages = with pkgs; [
    cosmic-wallpapers
    firmware-updater
  ];
}
