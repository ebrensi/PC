# This script is inspired by disko-install.
{
  pkgs ? import <nixpkgs> {},
  #
  nixosSystem,
  targetDrive ? "/dev/sdX",
  # Additional files to copy to the target system
  # ex. {"/path/on/target" = "/path/on/host";}
  extra-files ? {},
  # This writes EFI boot entries to the firmware of the machine it is running on.
  # Set this to true if we are running on the target machine
  writeEfiBootEntries ? false,
  ...
}: let
  lib = pkgs.lib;
  device-name = lib.strings.removePrefix "/dev/" targetDrive;
  originalSystem = nixosSystem;
  rootMountPoint = "/mnt/${hostname}-${device-name}";
  diskoSystem = originalSystem.extendModules {
    modules = [
      ({lib, ...}: {
        disko.rootMountPoint = lib.mkForce rootMountPoint;
        disko.devices.disk.main.device = lib.mkForce targetDrive;
      })
    ];
  };
  installSystem = originalSystem.extendModules {
    modules = [
      ({lib, ...}: {
        boot.loader.efi.canTouchEfiVariables = lib.mkForce writeEfiBootEntries;
      })
    ];
  };
  installToplevel = installSystem.config.system.build.toplevel;
  closureInfo = installSystem.pkgs.closureInfo {rootPaths = [installToplevel];};
  destFilesList = lib.concatStringsSep " " (builtins.attrNames extra-files);
  sourceFilesList = lib.concatStringsSep " " (builtins.attrValues extra-files);
  hostname = nixosSystem.config.networking.hostName;
in
  pkgs.writeShellScriptBin "install-${hostname}-to-${device-name}" ''
    device=${targetDrive}
    mountPoint=${rootMountPoint}
    nixos_system=${installToplevel}
    closure_info=${closureInfo}
    disko_script=${diskoSystem.config.system.build.diskoScript}  # we could make this mountScript if needed
    sourceFiles=(${sourceFilesList})
    destFiles=(${destFilesList})

    cleanupMountPoint() {
      echo "Cleaning up mount point..." >&2
      # Unmount everything recursively, multiple times to catch nested mounts
      for i in {1..5}; do
        if mountpoint -q "$mountPoint"; then
          umount -R "$mountPoint" 2>/dev/null || true
          sleep 0.5
        else
          break
        fi
      done

      # Check for any remaining mounts and force unmount
      if mountpoint -q "$mountPoint"; then
        echo "Warning: Forcing unmount of $mountPoint" >&2
        umount -f -R "$mountPoint" 2>/dev/null || true
      fi

      # Remove the directory (use rm -rf in case there are leftover files)
      if [[ -d "$mountPoint" ]]; then
        # Remove immutable flag from /var/empty if it exists
        if [[ -d "$mountPoint/var/empty" ]]; then
          chattr -i "$mountPoint/var/empty" 2>/dev/null || true
        fi
        rm -rf "$mountPoint" || echo "Warning: Could not remove $mountPoint" >&2
      fi
    }
    # check if we are root
    if [[ "$EUID" -ne 0 ]]; then
      echo "This script must be run as root" >&2
      exit 1
    fi

    mkdir -p "$mountPoint"
    chmod 755 "$mountPoint" # bcachefs wants 755
    trap cleanupMountPoint EXIT

    # We don't want swap as can break your running system in weird ways if you eject the disk
    DISKO_SKIP_SWAP=1 "$disko_script"

    xcp=${pkgs.xcp}/bin/xcp
    # if any files to copy
    if [ ''${#sourceFiles[@]} -ne 0 ]; then
      echo -e "\nCopying extra files to target system..." >&2
      for i in "''${!sourceFiles[@]}"; do
        src="''${sourceFiles[$i]}"
        dst="''${destFiles[$i]}"
        mkdir -p "$mountPoint$(dirname "$dst")"
        echo "Copying $src to $dst" >&2
        xcp -rL --no-perms "$src" "$mountPoint$dst"
      done
    fi

    # nix copy uses up a lot of memory and we work around issues with incorrect checksums in our store
    # that can be caused by using closureInfo in combination with multiple builders and non-deterministic builds.
    # Therefore if we have a blank store, we copy the store paths and registration from the closureInfo.
    if [[ ! -f "$mountPoint/nix/var/nix/db/db.sqlite" ]]; then
      echo "Copying store paths" >&2
      mkdir -p "$mountPoint/nix/store"
      xargs $xcp --recursive --target-directory "$mountPoint/nix/store"  < "$closure_info/store-paths"
      echo "Loading nix database" >&2
      NIX_STATE_DIR=$mountPoint/nix/var/nix nix-store --load-db < "$closure_info/registration"
    fi

    nixos-install --no-channel-copy --no-root-password --system "$nixos_system" --root "$mountPoint"
  ''
