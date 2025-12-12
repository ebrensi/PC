# Configuration specific to user "efrem"
{
  config,
  lib,
  pkgs,
  ...
}: let
  user = "efrem";
  public-keys = import ./secrets/public-keys.nix;
in {
  imports = [./dev-folders.nix];

  security.sudo.wheelNeedsPassword = false;
  users.mutableUsers = true;

  users.users.${user} = {
    isNormalUser = true;
    description = "Efrem Rensi";
    extraGroups = ["docker" "networkmanager" "wheel" "audio" "video" "lp"];
    packages = with pkgs; let
      dev-scripts = import ./dev-scripts.nix {inherit pkgs;};
    in [
      # https://search.nixos.org/packages?channel=unstable&
      micro
      termscp
      google-chrome
      claude-code
      visidata

      # Media
      vlc
      imagemagick
      alacritty
      # ffmpeg
      # gimp
      # shotcut
      # libreoffice-fresh

      dev-scripts.tmx
    ];
    initialPassword = "password";
    openssh.authorizedKeys.keys = with public-keys; [
      personal-ssh-key
      AP-ssh-key
      phone
    ];
  };
  nix.settings.trusted-users = [user];

  # Some files/folders that should exist
  systemd.tmpfiles.rules = let
    HOME = "/home/${user}";
    publicKeyFile = pkgs.writeText "id_ed25519.pub" public-keys.personal-ssh-key;
  in [
    "d  ${HOME}/dev                 775 ${user} users -"
    "L+ ${HOME}/.tigrc              600 ${user} users - /etc/tig/config"
    "L+ ${HOME}/.ssh/id_ed25519.pub 644    -           -   - ${publicKeyFile}"
  ];

  programs = {
    foot.enable = true;
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

        # Allow system clipboard access for nested tmux sessions
        # https://github.com/tmux/tmux/wiki/Clipboard#terminal-support---tmux-inside-tmux
        set -g set-clipboard on
        set -as terminal-features ',tmux*:clipboard'
        set -as terminal-features ',screen*:clipboard'
        set -as terminal-features ',xterm*:clipboard'
        set -s copy-command 'xsel -i'

        run-shell ${pkgs.tmuxPlugins.cpu}/share/tmux-plugins/cpu/cpu.tmux

        # https://github.com/tmux-plugins/tmux-continuum/blob/master/docs/faq.md
        run-shell ${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/continuum.tmux
        set -g @continuum-restore 'on'
        set -g @continuum-save-interval '60'
        set -g status-right "C: #{continuum_status} #[fg=black,bg=color15] #{cpu_percentage} %H:%M"
      '';
    };
    vscode = {
      extensions = with pkgs.vscode-extensions; let
        custom = pkgs.callPackage ./vscode-custom-extensions.nix {};
      in [
        ms-azuretools.vscode-containers
        ms-vscode.makefile-tools

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
        # SSH keepalive settings
        ServerAliveInterval 15
        ServerAliveCountMax 3
        TCPKeepAlive yes

        # SSH Multiplexing (re-enabled after fixing ssh-agent conflicts)
        ControlMaster auto
        ControlPath /tmp/ssh-%C
        ControlPersist 10s

        # Agent forwarding configuration
        ForwardAgent yes
        IdentityAgent $SSH_AUTH_SOCK
    '';
  };

  age.secrets = let
    HOME = "/home/${user}";
  in {
    personal-ssh-key = {
      file = ./secrets/efrem.age;
      path = "${HOME}/.ssh/id_ed25519";
      mode = "600";
      owner = "efrem";
    };
    AP-ssh-key = {
      file = ./secrets/AngelProtection-efrem.age;
      path = "${HOME}/.ssh/AngelProtection";
      mode = "600";
      owner = "efrem";
    };
    wakatime-cfg = {
      file = ./secrets/wakatime.age;
      path = "${HOME}/.wakatime.cfg";
      mode = "600";
      owner = "efrem";
    };
    aws-credentials = {
      file = ./secrets/aws-credentials.age;
      path = "${HOME}/.aws/credentials";
      mode = "644";
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
      flake-path = "/home/${user}/dev/PC";
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
      # SSH_AUTH_SOCK is set by NixOS ssh module when programs.ssh.startAgent = true
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

      write-zst-image () {
        # Usage: write-zst-image image.img.zst /dev/sdX
        zippedImage=$1
        device=$2
        ${pkgs.zstd}/bin/zstd -d $zippedImage -c | write-image - $device
      }

      title () {
        # Set terminal title
        echo -ne "\033]0;$1\007"
      }

      # Add SSH keys to the systemd ssh-agent
      ssh-add -q ${config.age.secrets.personal-ssh-key.path} 2>/dev/null
      ssh-add -q ${config.age.secrets.AP-ssh-key.path} 2>/dev/null
    '';
  };
}
