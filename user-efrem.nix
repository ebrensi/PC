# Configuration specific to user "efrem"
{
  config,
  lib,
  pkgs,
  #
  ...
}: let
  user = "efrem";
  public-keys = import ./secrets/public-keys.nix;
  avahi-service-type = "_${user}._tcp";
in {
  imports = [./dev-folders.nix];

  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 10;

  security.sudo.wheelNeedsPassword = false;
  users.mutableUsers = true;

  users.users.${user} = {
    isNormalUser = true;
    extraGroups = ["docker" "networkmanager" "wheel" "audio" "video" "lp"];
    packages = with pkgs; let
      dev-scripts = import ./dev-scripts.nix {inherit pkgs;};
    in [
      # https://search.nixos.org/packages?channel=unstable&
      micro
      termscp
      visidata
      glow
      nix-btm
      nix-top
      multitail
      wireguard-tools
      wg-friendly-peer-names
      tcpdump
      hwinfo
      powertop
      gitui
      gh

      dev-scripts.tmx

      # Networking
      socat

      nodejs # provides npx for MCP servers
    ];
    initialPassword = "password";
    openssh.authorizedKeys.keys = with public-keys; [
      personal-ssh-key
      AP-ssh-key
      phone
    ];
  };
  nix.settings.trusted-users = [user];

  # https://github.com/DieracDelta/nix-btm?tab=readme-ov-file#how-to-get-eagle-eye-viewjobs-view-to-work
  nix.extraOptions = "json-log-path = /tmp/nixbtm/nixbtm.sock";

  # Some files/folders that should exist
  systemd.tmpfiles.rules = let
    HOME = "/home/${user}";
    publicKeyFile = pkgs.writeText "id_ed25519.pub" public-keys.personal-ssh-key;
  in [
    "d  ${HOME}/dev                 775 ${user} users -"
    "L+ ${HOME}/.tigrc              600 ${user} users - /etc/tig/config"
    "L+ ${HOME}/.ssh/id_ed25519.pub 644    -           -   - ${publicKeyFile}"
    "d /tmp/nixbtm 0777 root root -"

    # Root SSH key for nix remote builders (copies user's key)
    "d  /root/.ssh                  700 root root -"
    "C+ /root/.ssh/id_ed25519       600 root root - ${HOME}/.ssh/id_ed25519"

    # Copy /etc/hosts nix store source to /etc/hosts, where it will be editable
    "R /etc/hosts"
    "C /etc/hosts 644 efrem users - ${config.environment.etc.hosts.source}"
  ];

  boot.initrd.systemd.services.contact-info = {
    description = "Display contact info on boot";
    wantedBy = ["initrd.target"];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "contact-info" ''
        echo -e "If found, please contact:\nEfrem Rensi\n+1510-282-9225...\nBarefootEfrem@gmail.com" \
          | ${pkgs.neo-cowsay}/bin/cowsay --bold --aurora -f dragon || true
      '');
    };
  };

  services.eternal-terminal.enable = true;
  services.avahi.extraServiceFiles = {
    guardian-cluster = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h</name>
        <service>
          <type>${avahi-service-type}</type>
        </service>
      </service-group>
    '';
  };

  programs = {
    tmux = {
      clock24 = true;
      terminal = "tmux-256color";
      baseIndex = 1;
      # dotbar must precede cpu so cpu can replace #{cpu_percentage} in the status-right dotbar sets.
      plugins = with pkgs.tmuxPlugins; [
        dotbar
        cpu
        # tmux-powerline
      ];
      # extraConfigBeforePlugins runs before plugin run-shells, so dotbar reads these options.
      # @tmux-dotbar-status-right is the v0.3.0 API (full format string used verbatim as status-right).
      extraConfigBeforePlugins = ''
        set -g @tmux-dotbar-right true
        set -g @tmux-dotbar-status-right "#[bg=#0B0E14,fg=#565B66] #(hostname)  #{cpu_percentage} %H:%M #[bg=#0B0E14,fg=#565B66]"
      '';
      extraConfig = ''
        set -g mouse on
        set -g focus-events on

        # Enable truecolor support for foot and xterm-256color terminals
        set -ag terminal-overrides ",foot:Tc,foot-direct:Tc,xterm-256color:Tc"

        # Allow system clipboard access for nested tmux sessions
        # https://github.com/tmux/tmux/wiki/Clipboard#terminal-support---tmux-inside-tmux
        set -g set-clipboard on
        set -as terminal-features ',tmux*:clipboard'
        set -s copy-command 'xsel -i'

        set-option -g set-titles on
        set-option -g set-titles-string "#{pane_title}"

        bind c new-window -c "#{pane_current_path}"
        bind '"' split-window -c "#{pane_current_path}"
        bind % split-window -h -c "#{pane_current_path}"

        set-option -g renumber-windows on
        set -g base-index 1
        setw -g pane-base-index 1
      '';
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
      push.autosetupremote = true;
    };
    # This would go in /etc/ssh/ssh_config in a traditional linux distro
    ssh.extraConfig = ''
      # Global SSH config for user efrem
      Host *
        IdentityFile /home/efrem/.ssh/AngelProtection
        IdentityFile /home/efrem/.ssh/id_ed25519

        # SSH keepalive settings
        ServerAliveInterval 15
        ServerAliveCountMax 3
        TCPKeepAlive yes

        ControlMaster auto
        ControlPath /tmp/ssh-%C
        ControlPersist 10s

        # Agent forwarding configuration
        ForwardAgent yes
        IdentityAgent $SSH_AUTH_SOCK

      Host vm
        Hostname 127.0.0.1
        Port 2222
    '';
    iftop.enable = true;
  };

  age.secrets = let
    HOME = "/home/${user}";
  in {
    wakatime-cfg = {
      file = ./secrets/wakatime.age;
      path = "${HOME}/.wakatime.cfg";
      mode = "600";
      owner = user;
    };
    aws-credentials = {
      file = ./secrets/aws-credentials.age;
      path = "${HOME}/.aws/credentials";
      mode = "644";
      owner = user;
    };
  };

  environment = {
    etc."tig/config".text = ''
      # tig configuration here
      set mouse = yes
      set mouse-scroll = 3
      set mouse-wheel-cursor = no

      bind status P !git push origin
      bind generic + !git commit --amend
      bind generic 9 @sh -c "echo -n %(commit) | xclip -selection c"
    '';
    # Convenient keyboard aliases
    shellAliases = let
      flake-path = "/home/${user}/dev/PC";
    in {
      flakeUpdate = "nix flake update --commit-lock-file --flake ${flake-path}";
      yay = ''nixos-rebuild switch --flake ${flake-path} --sudo |& nom; running=$(uname -r); new=$(ls /run/current-system/kernel-modules/lib/modules/); if [ "$running" != "$new" ]; then echo ""; echo "Kernel changed: $running -> $new. Reboot to apply."; fi'';
      N = "sudo -E nnn -dH";
      del = "trash-put";
      wg = "sudo wg";
      wgg = "sudo wgg";
      dev = "nix develop";
      code = "codium";
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

      title () {
        # Set terminal title
        echo -ne "\033]0;$1\007"
      }

      # Add SSH keys to the systemd ssh-agent
      ssh-add -q ~/.ssh/id_ed25519 2>/dev/null
      ssh-add -q ~/.ssh/AngelProtection 2>/dev/null

      myMachines () {
        ${pkgs.avahi}/bin/avahi-browse -tpr ${avahi-service-type} | grep -i "^=;.*;IP*" | awk -F';' '{print $4, $8}' | sort -u
      }
    '';
  };

  # Disable NixOS-managed /etc/hosts to allow manual modification
  environment.etc.hosts.enable = false;
  networking.extraHosts = let
    prefix = config.wireguard-peer.prefix;
  in ''
    ${prefix}1 adder-ws
    ${prefix}1 home
    ${prefix}2 thinkpad
    ${prefix}3 phone
    ${prefix}4 m1
  '';
  # aioboto3 15.5.0 tests fail against aiohttp 3.12+ (strict duplicate-header check).
  # Disable tests via overlay until nixpkgs fixes it upstream.
  nixpkgs.overlays = [
    (_: prev: {
      python3Packages = prev.python3Packages.overrideScope (_: pyPrev: {
        aioboto3 = pyPrev.aioboto3.overridePythonAttrs (_: {doCheck = false;});
      });
    })
  ];

  environment.etc."claude-code/managed-mcp.json".text = builtins.toJSON {
    mcpServers = {
      filesystem = {
        type = "stdio";
        command = "npx";
        args = ["-y" "@modelcontextprotocol/server-filesystem" "/home/${user}"];
      };
      nixos = {
        type = "stdio";
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
        args = [];
      };
    };
  };

  environment.etc."wireguard/peers".text = ''
    wa7WjWFn1SsOLQwOw3EMC1JY29WjU7vLvNlxRtySoTg=:thinkpad
    srov/ElxjM0BPfQHhCFN2sb3UEkwIhFQGSS55P/HIEA=:adder-ws
    Y5PxUuaIJi0emIQMkZW5EZDkSAY6Ed4ABAJdGlzpkTI=:phone
    aZEHKJGXFvCe8eOmMCdhD+okIuOkQUULZzKJZ+MWDRU=:m1
  '';
}
