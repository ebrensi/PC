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
    initialPassword = "rensi";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII//cI1RPUk4caXbGHdMJpQB7VuydedUCP/Kt9mALxVY Efrem-Laptop"
    ];
  };
  nix.settings.trusted-users = ["efrem"];
  services.displayManager.autoLogin = {
    enable = true;
    user = "efrem";
  };

  programs.ssh = {
      extraConfig = ''
        Host *.local
          StrictHostKeyChecking no
          UserKnownHostsFile /dev/null
          ForwardAgent yes

          # Reuse local ssh connections
          ControlPath /tmp/ssh/%r@%h:%p
          ControlMaster auto
          ControlPersist 20
      
        Host AP1
          Hostname 100.85.51.6
          User guardian
          ForwardAgent yes
          IdentityFile /home/efrem/.ssh/angelProtection

        Host ras.angelprotection.com
          StrictHostKeyChecking no
          UserKnownHostsFile /dev/null
          ForwardAgent yes

          ControlPath /tmp/ssh/%r@%h:%p
          ControlMaster auto
          ControlPersist 20
          IdentityFile /home/efrem/.ssh/angelProtection
        
        Host vm
          Hostname 127.0.0.1
          Port 2222
      '';
    };
}
