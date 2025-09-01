{
  config,
  lib,
  pkgs,
  ...
}: {
  # User Configuration
  security.sudo.wheelNeedsPassword = false;
  users.mutableUsers = true;

  users.users.efrem = {
    isNormalUser = true;
    description = "Efrem Rensi";
    extraGroups = ["networkmanager" "wheel" "audio" "video"];
    packages = with pkgs; [
      # Development
      git
      vim
      neovim
      micro
      vscode
      docker

      # COSMIC applications
      # cosmic-files
      # cosmic-edit
      # cosmic-term
      # cosmic-settings

      # Additional useful applications
      firefox
      google-chrome
      libreoffice

      # Media
      vlc
      ffmpeg
      gimp
      shotcut

      # Apps for productivity
      fastfetch
      speedtest-cli
      systemctl-tui
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII//cI1RPUk4caXbGHdMJpQB7VuydedUCP/Kt9mALxVY Efrem-Laptop"
    ];
  };
  nix.settings.trusted-users = ["efrem"];
}
