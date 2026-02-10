{
  config,
  lib,
  pkgs,
  ...
}: let
  user = "efrem";
in {
  environment.systemPackages = with pkgs; [
    google-chrome
    alacritty

    # AI coding tools
    claude-code
    gemini-cli
    opencode

    # Media
    mpvpaper # video wallpaper
    yt-dlp # Youtube downloader
    waytrogen # wallpaper manager
    mpv-unwrapped
    imagemagick
    wlr-randr
    zoom
    # ffmpeg
    # gimp
    # shotcut
    # libreoffice-fresh
  ];

  programs = {
    foot.enable = true;
    foot.settings = {
      main = {
        initial-color-theme = 1;
        font = "Noto Sans Mono:size=12";
      };
      colors = {
        alpha = 0.7;
      };
      csd = {
        preferred = "none";
      };
    };
    firefox = {
      enable = true;
      preferences = {
        # Hardware video acceleration via VA-API
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;
        "gfx.webrender.all" = true;
      };
    };
    xwayland.enable = true;
    vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; let
        custom = pkgs.callPackage ./vscode-custom-extensions.nix {};
      in [
        # Nix
        jnoortheen.nix-ide
        bbenoist.nix
        jeff-hykin.better-nix-syntax

        # Python
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

        # Go
        golang.go

        tamasfe.even-better-toml
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
        silofy.hackthebox
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
  };

  systemd.tmpfiles.rules = let
    HOME = "/home/${user}";
    mpvConfig = pkgs.writeText "mpv.conf" ''
      hwdec=auto
    '';
    chromeFlags = pkgs.writeText "chrome-flags.conf" ''
      --enable-features=VaapiVideoDecoder,VaapiVideoEncoder,VaapiVideoDecodeLinuxGL
      --disable-features=UseChromeOSDirectVideoDecoder
      --enable-gpu-rasterization
      --enable-zero-copy
    '';
  in [
    "d  ${HOME}/.config/mpv          755 ${user} users -"
    "L+ ${HOME}/.config/mpv/mpv.conf 644 ${user} users - ${mpvConfig}"
    "L+ ${HOME}/.config/chrome-flags.conf 644 ${user} users - ${chromeFlags}"
  ];

  services.printing = {
    # see https://wiki.nixos.org/wiki/Printing
    enable = true;
    cups-pdf.enable = true;
    browsing = true;
    drivers = [
      pkgs.cups-filters
      pkgs.cups-browsed
    ];
  };

  # Enable foot-server for user session with correct target
  systemd.user.services.foot-server = {
    description = "Foot terminal server";
    wantedBy = ["cosmic-session.target"];
    after = ["cosmic-session.target"];
    partOf = ["cosmic-session.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.foot}/bin/foot --server";
      Restart = "always";
      RestartSec = "1s";
    };
  };

  # Enable sound with pipewire (not Pulse Audio).
  # https://wiki.nixos.org/wiki/PipeWire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  hardware.bluetooth = {
    # https://nixos.wiki/wiki/Bluetooth
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Shows battery charge of connected devices on supported Bluetooth adapters.
        Experimental = true;
        # When enabled other devices can connect faster to us, however
        # the tradeoff is increased power consumption.
        FastConnectable = true;
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on.
        AutoEnable = true;
      };
    };
  };
}
