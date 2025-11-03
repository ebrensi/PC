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
  platform =
    if isIntelCpu
    then "intel"
    else if isAmdCpu
    then "amd"
    else "";
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
    boot = {
      kernelModules = ["kvm-${platform}" "vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio"];
      kernelParams = ["${platform}_iommu=on" "${platform}_iommu=pt" "kvm.ignore_msrs=1"];
      extraModprobeConfig = "options vfio-pci ids=${builtins.concatStringsSep "," vfioIds}";
    };

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
