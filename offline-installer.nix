{
  pkgs,
  lib,
  #
  systemToInstall,
  ...
}: let
  hostName = systemToInstall.config.networking.hostName;
  systemPkg = systemToInstall.config.system.build.toplevel;
  diskoScript = systemToInstall.config.system.build.diskoScript;
  mountScript = systemToInstall.config.system.build.mountScript;
  install-script = pkgs.writeShellApplication {
    name = "install-${hostName}";
    runtimeInputs = [pkgs.nixos-install-tools pkgs.gum];
    text = ''
      # This script is to be run from a system on a connected installer device,
      #  like a USB installer ISO.
      # set +u

      main() {
        echo "Installer script for NixOS system ${hostName}"
        echo "Format drive? If it's already formatted, say no!"
        if gum confirm; then
          DISKO_SKIP_SWAP=1 ${diskoScript}
        else
          echo "Writing to existing partitions"
          ${mountScript}
        fi

        # Ensure /mnt has correct permissions for nixos-install
        chmod 755 /mnt

        echo "Installing NixOS system to disk..."
        nixos-install --no-channel-copy --no-root-password --system ${systemPkg}
      }

      if main; then
        echo "${hostName} install succeeded"
      else
        echo "${hostName} install failed" >&2
        exit 1
      fi

      echo "Done! ${hostName} will reboot now."
      nohup sh -c 'sleep 3 && reboot' >/dev/null &
    '';
  };
in {
  environment.systemPackages = [install-script];
  services.getty.autologinUser = pkgs.lib.mkForce "root";
  environment.interactiveShellInit = "${pkgs.lib.getExe install-script}";
  services.getty.helpLine = pkgs.lib.mkForce "Run `install-${hostName}` from the command line to install aarch64-builder to a disk";
  isoImage.edition = hostName;

  # Include the system to install in the ISO's nix store
  isoImage.storeContents = [systemPkg];

  # Increase tmpfs size to handle installation
  boot.tmp.tmpfsSize = "75%";
}
