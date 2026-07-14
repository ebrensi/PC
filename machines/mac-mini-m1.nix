# this is hardware specific configuration for mac mini m1,
# assuming nixos was already installed via Asahi Linux as instructed in
# https://github.com/nix-community/nixos-apple-silicon/blob/main/docs/uefi-standalone.md
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = ["${modulesPath}/installer/scan/not-detected.nix"];
  networking.wireless.enable = false;

  boot = {
    # Use the systemd-boot EFI boot loader.
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = false;
    # Apple Silicon NVRAM is read-only from Linux; bootctl update always returns
    # non-zero even with --no-variables.  graceful makes the failure non-fatal.
    loader.systemd-boot.graceful = true;
    initrd.availableKernelModules = ["xhci_pci" "usbhid" "usb_storage"];
    initrd.kernelModules = [];
    kernelModules = [];
    extraModulePackages = [];
    supportedFilesystems = ["btrfs"];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/2d27792c-8d6c-4744-a0eb-1190bb91ff15";
      fsType = "ext4";
    };

    "/nix" = {
      device = "/dev/disk/by-uuid/744c8ca0-f54e-4c14-8ecc-0ba4ef363ae9";
      fsType = "ext4";
      options = ["noatime"];
      neededForBoot = true;
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/472B-1CEA";
      fsType = "vfat";
      options = ["fmask=0022" "dmask=0022"];
    };

    # USB NVMe SSD (SanDisk Extreme Pro 1.8TB)
    # Formatted with disko-usb-nvme.nix, provides:
    #   - /var/lib/docker: Docker storage (frees internal SSD)
    #   - /mnt/nix-alt: Secondary nix store for large builds
    #   - /mnt/usb-nvme: General storage
    #
    # nofail ensures system boots even if USB drive is disconnected
    "/var/lib/docker" = {
      device = "/dev/disk/by-label/usb-nvme";
      fsType = "btrfs";
      options = ["subvol=@docker" "compress=zstd" "noatime" "nodatacow" "nofail"];
    };

    "/mnt/nix-alt" = {
      device = "/dev/disk/by-label/usb-nvme";
      fsType = "btrfs";
      options = ["subvol=@nix-alt" "compress=zstd" "noatime" "nofail"];
    };

    "/mnt/usb-nvme" = {
      device = "/dev/disk/by-label/usb-nvme";
      fsType = "btrfs";
      options = ["subvol=@data" "compress=zstd" "noatime" "nofail"];
    };
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  hardware.asahi = {
    enable = true;
    extractPeripheralFirmware = false;
  };

  nix.settings = {
    extra-substituters = [
      "https://nixos-apple-silicon.cachix.org"
      # Local USB NVMe store - nix will automatically substitute from here
      # Build large packages with: nix build --store /mnt/nix-alt .#package
      # Then they're available locally without explicit copy
      "local?root=/mnt/nix-alt"
    ];
    extra-trusted-public-keys = [
      "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
    ];
    # Trust unsigned paths from local alt store
    require-sigs = false;
  };

  systemd.services = {
    # Docker storage lives on USB NVMe - don't start Docker without it
    docker = {
      after = ["var-lib-docker.mount"];
      bindsTo = ["var-lib-docker.mount"];
    };

    # Ensure correct ownership on the alt nix store after mount
    # The alt store is accessed directly (not via daemon) so efrem needs ownership
    nix-alt-store-permissions = {
      description = "Set permissions on alternate nix store";
      after = ["mnt-nix\\x2dalt.mount"];
      requires = ["mnt-nix\\x2dalt.mount"];
      wantedBy = ["mnt-nix\\x2dalt.mount"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'mkdir -p /mnt/nix-alt/nix/store /mnt/nix-alt/nix/var/nix && chown -R efrem:users /mnt/nix-alt/nix && chmod -R u+rwX /mnt/nix-alt/nix'";
      };
    };
  };
}
