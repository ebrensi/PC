{pkgs}: let
  sshOpts = "-A -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectionAttempts=5 -o ConnectTimeout=3";
  nom = "${pkgs.nix-output-monitor}/bin/nom";
in rec {
  nix-config = pkgs.writeText "nix-config" ''
    export NIX_CONFIG="
      max-jobs = 2
      warn-dirty = false
      always-allow-substitutes = true
      builders-use-substitutes = true
    "
  '';
  install-direct = pkgs.writeShellScriptBin "install-direct" ''
    # Usage: install-direct <flakePath> <host:port>

    flakePath=$1
    hostAndPort=$2
    IFS=':' read -r host port <<< "$hostAndPort"
    [ -n "$port" ] && PORT_OPT="-p $port"

    source ${nix-config}

    systemPath=$(${nom} build $flakePath.config.system.build.toplevel --no-link --print-out-paths) || {
      echo "Failed to build system closure"
      exit 1
    }

    ${pkgs.gum}/bin/gum confirm "Format Drive" && diskoScript=diskoScript || diskoScript=mountScript

    diskoScript=$(nix build $flakePath.config.system.build."$diskoScript" --no-link --print-out-paths) || {
      echo "Failed to build disko script"
      exit 1
    }

    echo "Installing $flakePath on $hostAndPort"
    ${pkgs.nixos-anywhere}/bin/nixos-anywhere  \
        --no-substitute-on-destination \
        --build-on auto \
        --store-paths $diskoScript $systemPath \
        --target-host $host $PORT_OPT
  '';

  copy-to = pkgs.writeShellScriptBin "copy-to" ''
    # Copy a nix store path directly to a remote machine via ssh
    # usage: copy-to <host:port> <path>

    hostAndPort=$1
    storePath=$2
    IFS=':' read -r host port <<< "$hostAndPort"
    sshOpts="${sshOpts}"
    [ -n "$port" ] && sshOpts="$sshOpts -p $port"
    echo "Copying $storePath closure to $host..." >&2

    source ${nix-config}

    NIX_SSHOPTS="$sshOpts" nix copy  \
      --no-check-sigs \
      --no-update-lock-file \
      --to "ssh-ng://$host" \
      "$storePath"

    # NIX_SSHOPTS="$sshOpts" nix-copy-closure -s --gzip --to "$host" "$storePath"
    echo "Done Copying."
  '';

  apply = pkgs.writeShellScriptBin "apply" ''
    storePath=$(realpath $1)
    sudo nix-env -p /nix/var/nix/profiles/system --set $storePath
    sudo $storePath/bin/switch-to-configuration switch
  '';

  deploy = pkgs.writeShellScriptBin "deploy" ''
    # Build the toplevel system closure of a nixosConfiguration and switch to it.
    #  By default the remote machine builds it; with -b it is built here and
    #  the closure copied over, so the remote machine builds nothing.
    # Usage: deploy [-b] <flakeAttr> [host[:port]]   (host defaults to <flakeAttr>.local)
    usage() {
      echo "Usage: deploy [-b] <flakeAttr> [host[:port]]" >&2
      exit 1
    }
    buildLocal=
    while getopts "b" opt; do
      case "$opt" in
        b) buildLocal=1 ;;
        *) usage ;;
      esac
    done
    shift $((OPTIND - 1))
    [ $# -ge 1 ] && [ $# -le 2 ] || usage

    flakeAttr="$1"
    dest="''${2:-$1.local}"
    IFS=':' read -r host port <<< "$dest"
    sshOpts="${sshOpts}"
    [ -n "$port" ] && sshOpts="$sshOpts -p $port"
    flakePath=".#nixosConfigurations.$flakeAttr.config.system.build.toplevel"

    if [ -n "$buildLocal" ]; then
      source ${nix-config}
      storePath=$(${nom} build --no-link --print-out-paths "$flakePath") || {
        echo "Failed to build system closure" >&2
        exit 1
      }
      ${copy-to}/bin/copy-to "$dest" "$storePath" || {
        echo "Failed to copy system closure to $dest" >&2
        exit 1
      }
    else
      storePath=$(NIX_SSHOPTS="$sshOpts" ${nom} build --no-link --print-out-paths \
        --eval-store auto --store "ssh-ng://$host" "$flakePath") || {
        echo "Failed to build system closure on $dest" >&2
        exit 1
      }
    fi

    echo "Switching to $storePath on $dest" >&2
    ssh $sshOpts "$host" "sudo nix-env -p /nix/var/nix/profiles/system --set $storePath" || exit 1
    ssh $sshOpts "$host" "sudo $storePath/bin/switch-to-configuration switch"
  '';

  tmx = pkgs.writeShellScriptBin "tmx" ''
    # Create/attach to a named tmux session
    # usage: tmx [session-name]
    if [ $# -eq 0 ]; then
      tmux list-sessions 2>/dev/null || echo "(no sessions)"
      exit 0
    fi
    SESSION_NAME=$1
    tmux new-session -As "$SESSION_NAME"
    echo -ne "\033]0;$$(hostname -s):$SESSION_NAME\007"
  '';

  check-patches = pkgs.writeShellScriptBin "check-patches" ''
    # Report which entries in patches/default.nix are still needed against the
    # pinned nixpkgs. Run from anywhere inside the repo.
    set -euo pipefail
    root=$(git rev-parse --show-toplevel)
    stock="(builtins.getFlake \"$root\").inputs.nixpkgs.legacyPackages.\''${builtins.currentSystem}"
    entries=$(nix eval --json --file "$root/patches" \
      --apply 'builtins.mapAttrs (_: e: { inherit (e) checked dropWhen; upstream = e.upstream or ""; })')

    for name in $(${pkgs.jq}/bin/jq -r 'keys[]' <<<"$entries"); do
      get() { ${pkgs.jq}/bin/jq -r --arg n "$name" ".[\$n].$1" <<<"$entries"; }
      case $(get dropWhen) in
        unpatched-builds)
          echo "== $name: building stock nixpkgs version..."
          if nix build --no-link --impure --expr "$stock.$name" 2>/dev/null; then
            echo "   DROP: builds without the patch. Remove it from patches/default.nix."
          else
            echo "   KEEP: stock build still fails. Bump 'checked'."
          fi
          ;;
        upstream-fixed)
          echo "== $name: check by hand: $(get upstream)"
          ;;
      esac
    done
  '';

  yay = pkgs.writeShellScriptBin "yay" ''
    # Build and activate this machine's config from the flake in ~/dev/PC.
    #
    # A live switch across a glibc version change breaks PAM for every process
    # started before it: they dlopen the new pam_unix.so, which needs symbols
    # their old libc lacks, so the COSMIC lock screen rejects every password.
    # When glibc changes, default to installing the new system for next boot.
    set -euo pipefail
    flake=''${YAY_FLAKE:-$HOME/dev/PC}
    host=$(hostname -s)

    new=$(${nom} build "$flake#nixosConfigurations.$host.config.system.build.toplevel" \
      --no-link --print-out-paths)

    # major.minor of the glibc systemd links against, e.g. 2.42
    glibc() {
      nix-store -q --references "$(readlink -f "$1/systemd")" |
        sed -n 's|.*-glibc-\([0-9]*\.[0-9]*\)-.*|\1|p'
    }
    oldGlibc=$(glibc /run/current-system)
    newGlibc=$(glibc "$new")

    action=switch
    if [ "$oldGlibc" != "$newGlibc" ]; then
      echo ""
      echo "glibc changed: $oldGlibc -> $newGlibc."
      echo "A live switch breaks login/unlock until reboot (PAM can't load under the old glibc)."
      if [ -t 0 ]; then
        action=$(${pkgs.gum}/bin/gum choose --header "Activate how?" boot switch cancel)
      else
        action=boot
      fi
    fi

    # --no-reexec: nixos-rebuild's self-update step ignores --store-path and
    # tries to evaluate <nixos-config>, which doesn't exist on a flake system.
    case $action in
      boot)
        nixos-rebuild boot --store-path "$new" --no-reexec --sudo
        echo ""
        echo "Installed for next boot. Reboot to apply."
        if [ -t 0 ] && ${pkgs.gum}/bin/gum confirm --default=false "Reboot now?"; then
          systemctl reboot
        fi
        ;;
      switch)
        nixos-rebuild switch --store-path "$new" --no-reexec --sudo
        running=$(uname -r)
        newKernel=$(ls "$new/kernel-modules/lib/modules/")
        if [ "$running" != "$newKernel" ]; then
          echo ""
          echo "Kernel changed: $running -> $newKernel. Reboot to apply."
        fi
        ;;
      *)
        exit 1
        ;;
    esac
  '';
}
