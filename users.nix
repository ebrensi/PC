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
      # https://search.nixos.org/packages?channel=unstable&

      # Development
      micro-full

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
      # So I can ssh access this machine from my laptop
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII//cI1RPUk4caXbGHdMJpQB7VuydedUCP/Kt9mALxVY Efrem-Laptop"
    ];
  };
  nix.settings.trusted-users = ["efrem"];

  # Auto Login
  services.displayManager.autoLogin = {
    enable = true;
    user = "efrem";
  };

  programs = {
    ssh = {
      # This is what would go in ~/.ssh/config in a traditional linux distro
      extraConfig = ''
        Host *.local
          StrictHostKeyChecking no
          UserKnownHostsFile /dev/null
          ForwardAgent yes

          # Reuse local ssh connections
          ControlPath /tmp/ssh/%r@%h:%p
          ControlMaster auto
          ControlPersist 20
          IdentityFile /home/efrem/.ssh/angelProtection

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
        custom = pkgs.callPackage ./vscode-custom-extensions.nix {};
      in [
        # For all extenstions
        # see https://search.nixos.org/packages?channel=unstable&query=vscode-extensions

        # Nix IDE
        jnoortheen.nix-ide
        bbenoist.nix
        jeff-hykin.better-nix-syntax

        # Color Themes
        teabyii.ayu
        nonylene.dark-molokai-theme
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
        custom.wesbos.theme-cobalt2

        # Utilities
        saoudrizwan.claude-dev
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

  environment.shellAliases = let
    flake-path = "/home/efrem/dev/PC";
  in {
    pc = "cd ${flake-path}";
    ap = "cd ~/dev/AngelProtection/Guardian/provision/nix";
    flakeUpdate = "nix flake update --commit-lock-file --flake ${flake-path}";
    yay = "nixos-rebuild switch --flake ${flake-path} --sudo";
  };

  environment.variables = {
    EDITOR = "micro";
    VISUAL = "micro";
    MICRO_TRUECOLOR = 1;
    NNN_TRASH = 1; # trash (needs trash-cli) instead of delete
    NNN_OPEN = "micro";
    NNN_GUI = 0;
    NNN_OPTS = "EAoau";
  };

  environment.interactiveShellInit = ''
    n ()
    {
        # Block nesting of nnn in subshells
        [ "''${NNNLVL:-0}" -eq 0 ] || {
            echo "nnn is already running"
            return
        }

        # The behaviour is set to cd on quit (nnn checks if NNN_TMPFILE is set)
        # If NNN_TMPFILE is set to a custom path, it must be exported for nnn to
        # see. To cd on quit only on ^G, remove the "export" and make sure not to
        # use a custom path, i.e. set NNN_TMPFILE *exactly* as follows:
        NNN_TMPFILE="''${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
        # export NNN_TMPFILE="''${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"

        # Unmask ^Q (, ^V etc.) (if required, see `stty -a`) to Quit nnn
        # stty start undef
        # stty stop undef
        # stty lwrap undef
        # stty lnext undef

        # The command builtin allows one to alias nnn to n, if desired, without
        # making an infinitely recursive alias
        command nnn "$@"

        [ ! -f "$NNN_TMPFILE" ] || {
            . "$NNN_TMPFILE"
            rm -f -- "$NNN_TMPFILE" > /dev/null
        }
    }
  '';
}
