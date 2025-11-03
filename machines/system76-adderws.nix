# Configuration Specific to System76 Adder WS Laptop WorkStation
{
  config,
  lib,
  pkgs,
  nixos-hardware,
  modulesPath,
  ...
}: {
  # hardware profiles from nixos-hardware
  imports = with nixos-hardware.nixosModules; [
    "${modulesPath}/installer/scan/not-detected.nix"
    system76
    common-cpu-intel
    common-gpu-intel
    common-gpu-nvidia # (GPU Offload mode)
    # common-gpu-nvidia-sync # (GPU Sync mode)
    common-pc-ssd
    common-pc-laptop
    common-hidpi
  ];

  boot = {
    initrd.availableKernelModules = ["xhci_pci" "nvme" "thunderbolt" "uas" "sd_mod" "sdhci_pci"];
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
  };

  # GPU Passthrough Configuration
  # IOMMU Group 11: 01:00.0 (NVIDIA RTX 4050) and 01:00.1 (NVIDIA Audio)
  # Set enable = false to use GPU on host instead of VMs
  virtualisation.gpuPassthrough = {
    enable = true;
    pciIds = [
      "10de:28a1" # GeForce RTX 4050 Max-Q
      "10de:22be" # NVIDIA Audio Controller
    ];
  };
  networking.useDHCP = lib.mkDefault true;

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    firmware = [pkgs.linux-firmware];
    nvidia = {
      open = true;
      nvidiaSettings = true;
      powerManagement.enable = true;
      powerManagement.finegrained = true;
      prime = {
        offload.enable = true;
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
    };
    nvidia-container-toolkit.enable = true;
    graphics.extraPackages = [
      pkgs.intel-compute-runtime # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-opencl-intel
      pkgs.intel-media-driver # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-va-api-intel
      pkgs.vpl-gpu-rt # https://wiki.nixos.org/wiki/Intel_Graphics
    ];
  };

  services = {
    # See https://support.system76.com/articles/system76-software/
    power-profiles-daemon.enable = false;
  };

  # see https://wiki.archlinux.org/title/Hardware_video_acceleration#Verification
  environment.systemPackages = with pkgs; [
    libva-utils # for vainfo
    vdpauinfo # vdpauinfo
    vulkan-tools # vulkaninfo
    intel-gpu-tools # intel_gpu_top
  ];
}
