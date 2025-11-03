# GPU Passthrough Module for QEMU/KVM Virtual Machines
# This module configures VFIO for passing through a GPU to VMs
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.virtualisation.gpuPassthrough;

  # Auto-detect CPU vendor based on microcode settings
  isIntelCpu = config.hardware.cpu.intel.updateMicrocode or false;
  isAmdCpu = config.hardware.cpu.amd.updateMicrocode or false;
in {
  options.virtualisation.gpuPassthrough = {
    enable = lib.mkEnableOption "GPU passthrough for QEMU/KVM VMs";

    pciIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "PCI vendor:device IDs to bind to VFIO (e.g., ['10de:28a1', '10de:22be'])";
      example = ["10de:28a1" "10de:22be"];
    };

    blacklistDrivers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["nvidia" "nvidia_drm" "nvidia_modeset" "nouveau"];
      description = "Kernel modules to blacklist to prevent them from claiming the GPU";
    };
  };

  config = lib.mkIf cfg.enable {
    # Auto-detect and enable appropriate IOMMU
    boot.kernelParams =
      lib.optional isIntelCpu "intel_iommu=on"
      ++ lib.optional isAmdCpu "amd_iommu=on"
      ++ ["iommu=pt"]; # passthrough mode for better performance

    # Load VFIO modules early in initrd
    boot.initrd.kernelModules = [
      "vfio"
      "vfio_iommu_type1"
      "vfio_pci"
    ];

    # Bind specified PCI devices to VFIO driver
    boot.extraModprobeConfig = let
      ids = lib.concatStringsSep "," cfg.pciIds;
    in ''
      options vfio-pci ids=${ids}
      softdep nvidia pre: vfio-pci
    '';

    # Blacklist GPU drivers to prevent host from claiming the GPU
    boot.blacklistedKernelModules = cfg.blacklistDrivers;

    # Ensure libvirtd is enabled for VM management
    virtualisation.libvirtd.enable = lib.mkDefault true;

    # Add helpful packages for GPU passthrough
    environment.systemPackages = with pkgs; [
      virt-manager # GUI for managing VMs
      OVMF # UEFI firmware for VMs (required for GPU passthrough)
    ];
  };
}
