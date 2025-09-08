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

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # This is so symbols in Starship prompt are rendered correctly.
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
  ];

  boot.kernelParams = ["nvidia_drm.fbdev=1"];

  # prevent system from auto-sleeping
  # systemd.targets.sleep.enable = false;
  # systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Flatpak support for COSMIC Store
  services.flatpak.enable = true;
  environment.systemPackages = [pkgs.cosmic-store];
  programs.ssh.startAgent = lib.mkForce false;
}
