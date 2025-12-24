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

        echo "Installing NixOS system to disk..."
        sudo nixos-install --no-channel-copy --no-root-password --system ${systemPkg}
      }

      if main; then
        echo "${hostName} install succeeded"
      else
        echo "${hostName} install failed" >&2
        exit 1
      fi

      echo "Done! ${hostName} will reboot now."
      nohup sh -c 'sleep 3 && sudo reboot' >/dev/null &
    '';
  };
in {
  environment.systemPackages = [install-script];
  services.getty.autologinUser = pkgs.lib.mkForce "nixos";
  environment.interactiveShellInit = "${install-script}/bin/*";
  services.getty.helpLine = pkgs.lib.mkForce "Run `install-${hostName}` from the command line to install aarch64-builder to a disk";
  isoImage.edition = hostName;
  # isoImage.includeSystemBuildDependencies = true;
}
