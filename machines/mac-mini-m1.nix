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

  boot.initrd.availableKernelModules = ["xhci_pci" "usbhid" "usb_storage"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];
  boot.supportedFilesystems = ["btrfs"];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/2d27792c-8d6c-4744-a0eb-1190bb91ff15";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
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
  fileSystems."/var/lib/docker" = {
    device = "/dev/disk/by-label/usb-nvme";
    fsType = "btrfs";
    options = ["subvol=@docker" "compress=zstd" "noatime" "nodatacow" "nofail"];
  };

  fileSystems."/mnt/nix-alt" = {
    device = "/dev/disk/by-label/usb-nvme";
    fsType = "btrfs";
    options = ["subvol=@nix-alt" "compress=zstd" "noatime" "nofail"];
  };

  fileSystems."/mnt/usb-nvme" = {
    device = "/dev/disk/by-label/usb-nvme";
    fsType = "btrfs";
    options = ["subvol=@data" "compress=zstd" "noatime" "nofail"];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  hardware.asahi.extractPeripheralFirmware = false;

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
  };
}
