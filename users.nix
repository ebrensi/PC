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
      docker

      # Additional useful applications
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

      nix-direnv
      direnv
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

  programs.yazi.enable = true;
  programs.starship.enable = true;
  programs.zoom-us.enable = true;
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      # Nix stuff
      jnoortheen.nix-ide
      bbenoist.nix
      jeff-hykin.better-nix-syntax

      # Themes
      arcticicestudio.nord-visual-studio-code
      teabyii.ayu

      yzane.markdown-pdf
      wakatime.vscode-wakatime
      waderyan.gitblame
      timonwong.shellcheck
      mechatroner.rainbow-csv
      kamadorueda.alejandra
      jgclark.vscode-todo-highlight
      irongeek.vscode-env
      golang.go
      github.copilot
      esbenp.prettier-vscode
      davidanson.vscode-markdownlint
      codezombiech.gitignore
      wmaurer.change-case
      # shardulm94.trailing-spaces
      # stephlin.vscode-tmux-keybinding

      # Python stuff
      ms-toolsai.jupyter
      ms-python.python
      ms-python.vscode-pylance
      ms-python.pylint
      # ms-python.flake8
      ms-python.mypy-type-checker
      ms-python.isort
      ms-python.debugpy
      ms-python.black-formatter
      charliermarsh.ruff
    ];
  };
  services.tailscale.enable = true;

  environment.shellAliases = {
    pc = "cd ~/dev/PC";
    ap = "cd ~/dev/AngelProtection/Guardian/provision/nix";
  };
}
