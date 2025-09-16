{
  config,
  lib,
  pkgs,
  ...
}: let
  main-user = "efrem";
in {
  imports = [./dev-folders.nix];

  security.sudo.wheelNeedsPassword = false;
  users.mutableUsers = true;

  users.users.${main-user} = {
    isNormalUser = true;
    description = "Efrem Rensi";
    extraGroups = ["networkmanager" "wheel" "audio" "video"];
    packages = with pkgs; [
      # https://search.nixos.org/packages?channel=unstable&

      # Development
      micro-full
      ghq

      # Additional useful applications
      google-chrome
      libreoffice
      claude-code

      # Media
      vlc
      ffmpeg
      gimp
      shotcut
    ];
    initialPassword = "password";
    openssh.authorizedKeys.keys = [
      # So I can ssh access this machine from my laptop
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII//cI1RPUk4caXbGHdMJpQB7VuydedUCP/Kt9mALxVY Efrem-Laptop"
    ];
  };
  nix.settings.trusted-users = [main-user];

  services = {
    # cosmic doesn't have good bluetooth support yet, so use blueman for now
    blueman.enable = true;

    # Auto Login
    displayManager.autoLogin = {
      enable = true;
      user = main-user;
    };
  };

  # Some files/folders that should exist
  systemd.tmpfiles.rules = [
    "d /tmp/ssh                 777 root root -"
    "d /home/${main-user}/dev   775 ${main-user} users -"
    "L /home/${main-user}/.tigrc - - - - /etc/tig/config"
  ];

  programs = {
    ssh = {
      # This is what would go in ~/.ssh/config in a traditional linux distro
      extraConfig = ''
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        IdentityFile /home/${main-user}/.ssh/angelProtection
        ForwardAgent yes
        AddKeysToAgent yes

        # Reuse local ssh connections
        ControlPath /tmp/ssh/%r@%h:%p
        ControlMaster auto
        ControlPersist 20

        Host AP1
          Hostname 100.85.51.6
          User guardian

        Host vm
          Hostname 127.0.0.1
          Port 2222
      '';
    };
    zoom-us.enable = true;
    vscode = {
      extensions = with pkgs.vscode-extensions; let
        custom = pkgs.callPackage ./vscode-custom-extensions.nix {};
      in [
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
        github.copilot
        esbenp.prettier-vscode
        davidanson.vscode-markdownlint
        codezombiech.gitignore
        wmaurer.change-case
        custom.ktnrg45.vscode-cython
        # shardulm94.trailing-spaces
        # stephlin.vscode-tmux-keybinding
      ];
    };
    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };
    git.config = {
      init.defaultBranch = "main";
      user = {
        name = "Efrem";
        email = "rensi.efrem@gmail.com";
      };
      color.ui = "auto";
      push.autosetupremote = true;
    };
  };
  environment = {
    etc."tig/config".text = ''
      # tig configuration here
      set mouse = yes
      set mouse-scroll = 3
      set mouse-wheel-cursor = no

      bind status P !git push origin
    '';
    # Convenient keyboard aliases
    shellAliases = let
      flake-path = "/home/${main-user}/dev/PC";
    in {
      pc = "cd ${flake-path}";
      ap = "cd ~/dev/AngelProtection/Guardian/provision/nix";
      flakeUpdate = "nix flake update --commit-lock-file --flake ${flake-path}";
      yay = "nixos-rebuild switch --flake ${flake-path} --sudo";
    };

    # Environment Variables (for this user)
    sessionVariables = {
      EDITOR = "micro";
      VISUAL = "micro";
      MICRO_TRUECOLOR = 1;
      NNN_TRASH = 1; # trash (needs trash-cli) instead of delete
      NNN_OPEN = "micro";
      NNN_GUI = 0;
      NNN_OPTS = "EAoau";
    };

    # This runs when a new shell is started (for this user)
    # This would be like putting stuff in ~/.bashrc
    interactiveShellInit = ''
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

      ssh-add ~/.ssh/angelProtection &>/dev/null
    '';
  };

  nix = {
    settings.substituters = lib.mkBefore [
      "https://guardian-ops-nix.s3.amazonaws.com" # Guardian nix cache
    ];
    settings.trusted-public-keys = ["guardian-nix-cache:vN2kJ7sUQSbyWv4908FErdTS0VrPnMJtKypt21WzJA0="];
    # distributedBuilds = true;
    # # optional, useful when the builder has a faster internet connection than yours
    # extraOptions = ''
    #   builders-use-substitutes = true
    # '';
    # buildMachines = [
    #   {
    #     hostName = "AP1";
    #     sshUser = "efrem";
    #     protocol = "ssh-ng";
    #     sshKey = "/home/efrem/.ssh/angelProtection.pub";
    #     systems = ["x86_64-linux" "aarch64-linux"];
    #     maxJobs = 3;
    #     speedFactor = 2;
    #     supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    #     # mandatoryFeatures = [];
    #   }
    # ];
  };
}
