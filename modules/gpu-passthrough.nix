# GPU Passthrough Module for QEMU/KVM Virtual Machines
# This module configures VFIO for passing through a GPU to VMs
{
  config,
  lib,
  pkgs,
  ...
}: let
  user = "efrem";
  cfg = config.virtualisation.gpuPassthrough;

  # Auto-detect CPU vendor based on microcode settings
  isIntelCpu = config.hardware.cpu.intel.updateMicrocode or false;
  isAmdCpu = config.hardware.cpu.amd.updateMicrocode or false;
  platform =
    if isIntelCpu
    then "intel"
    else if isAmdCpu
    then "amd"
    else throw "Unable to detect CPU vendor for IOMMU configuration. Please ensure microcode settings are correct.";
in {
  options.virtualisation.gpuPassthrough = {
    enable = lib.mkEnableOption "GPU passthrough for QEMU/KVM VMs";

    pciIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "PCI vendor:device IDs to bind to VFIO (e.g., ['10de:28a1', '10de:22be'])";
      example = ["10de:28a1" "10de:22be"];
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;
    users.users.${user}.extraGroups = ["libvirtd" "kvm"];

    boot.kernelParams = [
      "${platform}_iommu=on"
      "iommu=pt"
      "vfio-pci.ids=${builtins.concatStringsSep "," cfg.pciIds}"
    ];
    boot.initrd.kernelModules = lib.mkBefore [
      "vfio_pci"
      "vfio"
      "vfio_iommu_type1"
      "vfio_virqfd"
    ];

    # Blacklist GPU drivers to prevent host from claiming the GPU
    boot.blacklistedKernelModules = ["nvidia" "nvidia_drm" "nvidia_modeset" "nouveau" "i2c_nvidia_gpu"];

    # Allow users in kvm group to access VFIO devices
    services.udev.extraRules = ''
      SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm", MODE="0660"
    '';

    virtualisation.spiceUSBRedirection.enable = true;
  };
}
