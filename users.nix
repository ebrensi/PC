{
  config,
  lib,
  pkgs,
  ...
}: {
  # User Configuration
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

      # Archive tools
      unzip
      p7zip
    ];
  };
}
