# Configuration specific to user "efrem"
{
  config,
  lib,
  pkgs,
  ...
}: let
  main-user = "efrem";
  public-keys = import ./secrets/public.nix;
in {
  imports = [./dev-folders.nix];

  security.sudo.wheelNeedsPassword = false;
  users.mutableUsers = true;

  users.users.${main-user} = {
    isNormalUser = true;
    description = "Efrem Rensi";
    extraGroups = ["docker" "networkmanager" "wheel" "audio" "video" "lp"];
    packages = with pkgs; [
      # https://search.nixos.org/packages?channel=unstable&
      micro
      google-chrome
      claude-code

      # Media
      vlc
      imagemagick
      # ffmpeg
      # gimp
      # shotcut
      # libreoffice-fresh
    ];
    initialPassword = "password";
    openssh.authorizedKeys.keys = with public-keys; [
      personal-ssh-key
      AP-ssh-key
    ];
  };
  nix.settings.trusted-users = [main-user];

  # Some files/folders that should exist
  systemd.tmpfiles.rules = let
    homeDir = "/home/${main-user}";
    publicKeyFile = pkgs.writeText "id_ed25519.pub" public-keys.personal-ssh-key;
    aws-credentials = pkgs.writeText "aws-credentials" ''
      [default]
      aws_access_key_id =
      aws_secret_access_key =

      [guardian]
      aws_access_key_id =
      aws_secret_access_key =
    '';
  in [
    "d ${homeDir}/dev                  775 ${main-user} users -"
    "L+ ${homeDir}/.tigrc              664 ${main-user} users - /etc/tig/config"
    "L+ ${homeDir}/.ssh/id_ed25519.pub -    -           -     - ${publicKeyFile}"
    "d ${homeDir}/.aws                 775 ${main-user} users -"
    "C ${homeDir}/.aws/credentials     664 ${main-user} users - ${aws-credentials}"
  ];

  programs = {
    tmux = {
      clock24 = true;
      terminal = "screen-256color";
      plugins = with pkgs.tmuxPlugins; [
        cpu
        continuum
        resurrect
      ];
      extraConfig = ''
        set -g mouse on
        set -g status-right "#[fg=black,bg=color15] #{cpu_percentage} %H:%M"
        run-shell ${pkgs.tmuxPlugins.cpu}/share/tmux-plugins/cpu/cpu.tmux
        set -g @continuum-restore 'on'
        set -g @continuum-boot 'on'
        # set -g @continuum-save-interval '60'
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
        IdentityFile ${config.age.secrets.personal-ssh-key.path}
        IdentityFile ${config.age.secrets.AP-ssh-key.path}
    '';
  };

  age.secrets = {
    personal-ssh-key = {
      file = ./secrets/efrem.age;
      path = "/home/${main-user}/.ssh/id_ed25519";
      mode = "600";
      owner = "efrem";
    };
    AP-ssh-key = {
      file = ./secrets/AngelProtection-efrem.age;
      path = "/home/${main-user}/.ssh/AngelProtection";
      mode = "600";
      owner = "efrem";
    };
    guardian-envrc = {
      file = ./secrets/guardian-envrc.age;
      path = "/home/${main-user}/.guardian-envrc";
      mode = "600";
      owner = "efrem";
    };
    wakatime-cfg = {
      file = ./secrets/wakatime.age;
      path = "/home/${main-user}/.wakatime.cfg";
      mode = "600";
      owner = "efrem";
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
      yay = "nixos-rebuild switch --flake ${flake-path} --sudo |& nom";
      N = "sudo -E nnn -dH";
      del = "trash-put";
    };

    # Environment Variables (for this user)
    sessionVariables = {
      EDITOR = "micro";
      VISUAL = "micro";
      MICRO_TRUECOLOR = 1;
      NNN_TRASH = 1; # trash (needs trash-cli) instead of delete
      NNN_OPEN = "micro";
      NNN_GUI = 0;
      NNN_OPTS = "EAoaux";
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

      write-image () {
        # Usage: write-image image.img /dev/sdX
        image=$1
        device=$2
        echo "Writing $image to $device"
        sudo dd if=$image of=$device status=progress bs=4M conv=fsync oflag=direct && sudo eject $device && echo "Device $device ejected. You may now remove it."
      }
      export -f write-image

      write-zst-image () {
        # Usage: write-zst-image image.img.zst /dev/sdX
        zippedImage=$1
        device=$2
        ${pkgs.zstd}/bin/zstd -d $zippedImage -c | write-image - $device
      }
      export -f write-zst-image

      title () {
        # Set terminal title
        echo -ne "\033]0;$1\007"
      }
      export -f title

      tmx () {
        # Start a tmux named session if not already inside one and set the terminal title
        title "$1"
        tmux new-session -As $1
      }
      export -f tmx
    '';
  };
}
