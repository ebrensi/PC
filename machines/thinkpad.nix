{
  config,
  lib,
  pkgs,
  modulesPath,
  #
  nixos-hardware,
  ...
}: {
  imports = [
    nixos-hardware.nixosModules.lenovo-thinkpad-x1-11th-gen
    "${modulesPath}/installer/scan/not-detected.nix"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  # Intel GPU hardware acceleration for video decoding
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver # VAAPI for hardware video decoding
    vpl-gpu-rt # Intel Video Processing Library
  ];

  # GPU diagnostic tools
  environment.systemPackages = with pkgs; [
    libva-utils # vainfo command to verify VAAPI
    intel-gpu-tools # intel_gpu_top to monitor GPU usage
  ];

  # fileSystems."/" = {
  #   device = "/dev/disk/by-uuid/016bb68b-b54d-4490-8fd8-35d1c42d6dba";
  #   fsType = "btrfs";
  #   options = ["subvol=root"];
  # };

  # fileSystems."/nix" = {
  #   device = "/dev/disk/by-uuid/016bb68b-b54d-4490-8fd8-35d1c42d6dba";
  #   fsType = "btrfs";
  #   options = ["subvol=nix"];
  # };

  # fileSystems."/home" = {
  #   device = "/dev/disk/by-uuid/016bb68b-b54d-4490-8fd8-35d1c42d6dba";
  #   fsType = "btrfs";
  #   options = ["subvol=home"];
  # };

  # fileSystems."/snapshots" = {
  #   device = "/dev/disk/by-uuid/016bb68b-b54d-4490-8fd8-35d1c42d6dba";
  #   fsType = "btrfs";
  #   options = ["subvol=snapshots"];
  # };

  # fileSystems."/boot" = {
  #   device = "/dev/disk/by-uuid/3AAC-D675";
  #   fsType = "vfat";
  #   options = ["fmask=0077" "dmask=0077"];
  # };

  # fileSystems."/swap" = {
  #   device = "/dev/disk/by-uuid/016bb68b-b54d-4490-8fd8-35d1c42d6dba";
  #   fsType = "btrfs";
  #   options = ["subvol=swap"];
  # };

  # fileSystems."/var/lib/docker/overlay2/c81d03fdb23bf79f55a3a766c9b75d36e6e8676dd3977267df3c7603c9802af8/merged" = {
  #   device = "overlay";
  #   fsType = "overlay";
  # };

  # swapDevices = [];
}
