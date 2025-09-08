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
      claude-code

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

  programs = {
    ssh = {
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
    yazi.enable = true;
    starship.enable = true;
    zoom-us.enable = true;
    vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; let
        custom = import ./vscode-custom-extensions.nix;
      in [
        # Nix IDE
        jnoortheen.nix-ide
        bbenoist.nix
        jeff-hykin.better-nix-syntax

        # Color Themes
        arcticicestudio.nord-visual-studio-code
        teabyii.ayu
        nonylene.dark-molokai-theme
        piousdeer.adwaita-theme
        github.github-vscode-theme
        ms-vscode.theme-tomorrowkit
        catppuccin.catppuccin-vsc
        dracula-theme.theme-dracula
        hiukky.flate
        emroussel.atomize-atom-one-dark-theme
        nur.just-black
        johnpapa.winteriscoming
        jdinhlife.gruvbox
        silofy.hackthebox
        sainnhe.gruvbox-material
        naumovs.theme-oceanicnext
        dhedgecock.radical-vscode
        custom.ahmadawais.shades-of-purple
        custom.liviuschera.noctis

        # Utilities
        anthropic.claude-code
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
        custom.ktnrg45.vscode-cython
        # shardulm94.trailing-spaces
        # stephlin.vscode-tmux-keybinding

        # Python IDE
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
    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };
  };
  services.tailscale.enable = true;

  environment.shellAliases = {
    pc = "cd ~/dev/PC";
    ap = "cd ~/dev/AngelProtection/Guardian/provision/nix";
  };
}
