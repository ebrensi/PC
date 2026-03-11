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

    targetHost=$1
    storePath=$2
    echo "Copying $storePath closure to $host..." >&2
    sshOpts="${sshOpts}"

    source ${nix-config}

    NIX_SSHOPTS="$sshOpts" nix copy  \
      --no-check-sigs \
      --no-update-lock-file \
      --to "ssh-ng://$targetHost" \
      "$storePath"

    # NIX_SSHOPTS="$sshOpts" nix-copy-closure -s --gzip --to "$targetHost" "$storePath"
    echo "Done Copying."
  '';
  deploy-binaries = pkgs.writeShellScriptBin "deploy-binaries" ''
    # Build toplevel of an arbitrary flake path locally, copy the closure it directly to a remote machine,
    #  and activate it there. Use this script to update the NixOS system already running on a remote machine,
    #  without using the remote cache.
    # Usage: deploy-binaries <flakePath> <host:port>

    source ${nix-config}

    flakePath=$1
    targetHost=$2
    system=$(${nom} build $flakePath.config.system.build.toplevel) || {
      echo "Failed to build system closure"
      exit 1
    }
    ${copy-to}/bin/* "$targetHost" $system || {
      echo "Failed to copy system closure to remote machine"
      exit 1
    }
    sshOpts="${sshOpts}"
    ssh $sshOpts $dest "sudo nix-env -p /nix/var/nix/profiles/system --set $system"
    ssh $sshOpts $dest "sudo $system/bin/switch-to-configuration switch"
  '';
  apply = pkgs.writeShellScriptBin "apply" ''
    storePath=$(realpath $1)
    sudo nix-env -p /nix/var/nix/profiles/system --set $storePath
    sudo $storePath/bin/switch-to-configuration switch
  '';
  remote-build = pkgs.writeShellScriptBin "remote-build" ''
    # Build toplevel of an arbitrary flake path *on* a remote machine and return the store path.
    flakeAttr="$1"
    dest="$2"
    echo "Building $flakeAttr on the machine at $dest" >&2
    flakePath="''${flakeAttr}.config.system.build.toplevel"
    storePath=$(${nom} build --eval-store auto --store ssh-ng://$dest $flakePath --print-out-paths) || {
      echo "Failed to build system closure on remote machine" >&2
      exit 1
    }
    echo "Built $storePath on nix store at $dest" >&2
    echo $storePath
  '';

  remote-build-deploy = pkgs.writeShellScriptBin "remote-build-deploy" ''
    # Build toplevel system closure of an arbitrary flake path on a remote machine, and switch to it.
    flakeAttr="$1"
    dest="$2"
    flakePath="''${flakeAttr}.config.system.build.toplevel"
    storePath=$(${remote-build}/bin/* $flakeAttr $dest)
    echo "Switching to $storePath on nix store at $dest" >&2
    sshOpts="${sshOpts}"
    ssh $sshOpts $dest "sudo nix-env -p /nix/var/nix/profiles/system --set $storePath"
    ssh $sshOpts $dest "sudo $storePath/bin/switch-to-configuration switch"
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
}
