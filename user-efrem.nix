# Configuration specific to user "efrem"
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
      micro

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
    # Auto Login
    displayManager.autoLogin = {
      enable = true;
      user = main-user;
    };
  };

  # Some files/folders that should exist
  systemd.tmpfiles.rules = [
    "d /home/${main-user}/dev   775 ${main-user} users -"
    "L /home/${main-user}/.tigrc - - - - /etc/tig/config"
  ];

  programs = {
    zoom-us.enable = true;
    tmux = {
      clock24 = true;
      terminal = "screen-256color";
      plugins = [
        pkgs.tmuxPlugins.cpu
        pkgs.tmuxPlugins.continuum
        pkgs.tmuxPlugins.resurrect
      ];
      extraConfig = ''
        set -g mouse on
        set -g status-right "#[fg=black,bg=color15] #{cpu_percentage} %H:%M"
        run-shell ${pkgs.tmuxPlugins.cpu}/share/tmux-plugins/cpu/cpu.tmux
      '';
    };
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
        redhat.vscode-yaml
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
      silent = true;
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
    # This would go in /etc/ssh/ssh_config in a traditional linux distro
    ssh.extraConfig = ''
      # Global SSH config for user efrem
      Host *
        IdentityFile /home/efrem/.ssh/angelProtection
    '';
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
      yay = "nixos-rebuild switch --flake ${flake-path} --sudo |& nom";
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

      write-zst-image () {
        # Usage: write-zst-image image.img.zst /dev/sdX
        image=$1
        device=$2
        echo "Writing $image to $device"
        ${pkgs.zstd}/bin/zstd -d $image -c | sudo dd if=$image of=$device status=progress bs=4M conv=fsync oflag=direct && sudo eject $device && echo "Device $device ejected. You may now remove it."
      }
      export -f write-zst-image

      topen () {
        # Start a tmux named session if not already inside one
        tmux new-session -As $1
      }
      export -f topen
    '';
  };

  nix = {
    settings.substituters = let
      mkArgstr = args: builtins.concatStringsSep "&" (map (k: "${k}=${args.${k}}") (builtins.attrNames args));
      url-args = {
        # see https://nix.dev/manual/nix/2.25/store/types/http-binary-cache-store
        parallel-compression = "true";
        compression = "zstd";
        compression-level = "3";
        path-info-cache-size = "131072";
        want-mass-query = "true";
      };
      args = mkArgstr url-args;
    in [
      "https://guardian-ops-nix.s3.us-west-2.amazonaws.com?${args}&priority=1"
      "https://cache.nixos.org?${args}&priority=10"
    ];
    settings.trusted-public-keys = ["guardian-nix-cache:vN2kJ7sUQSbyWv4908FErdTS0VrPnMJtKypt21WzJA0="];
  };
}
