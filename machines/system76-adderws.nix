# Configuration Specific to System76 Adder WS Laptop WorkStation
# Hardware config inlined (no nixos-hardware dependency)
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/scan/not-detected.nix"
  ];

  boot = {
    initrd.availableKernelModules = ["xhci_pci" "nvme" "thunderbolt" "uas" "sd_mod" "sdhci_pci"];
    initrd.kernelModules = ["i915"]; # Load Intel GPU early for console
    kernelModules = ["kvm-intel" "iwlwifi"];
    extraModulePackages = [];
  };
  networking.useDHCP = lib.mkDefault true;

  # SSD optimization (from common-pc-ssd)
  services.fstrim.enable = true;

  # System76 hardware support
  hardware.system76.enableAll = true;

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    firmware = [pkgs.linux-firmware];

    # Graphics - NVIDIA hybrid with Intel iGPU
    graphics.enable = true;
    graphics.extraPackages = [
      pkgs.intel-compute-runtime # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-opencl-intel
      pkgs.intel-media-driver # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-va-api-intel
      pkgs.vpl-gpu-rt # https://wiki.nixos.org/wiki/Intel_Graphics
    ];

    nvidia = {
      open = true;
      nvidiaSettings = false;
      powerManagement.enable = true;
      powerManagement.finegrained = true;
      prime = {
        offload.enable = true;
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
    };
    nvidia-container-toolkit.enable = true;
  };

  services = {
    # See https://support.system76.com/articles/system76-software/
    power-profiles-daemon.enable = false;
    # NVIDIA driver (from common-gpu-nvidia)
    xserver.videoDrivers = ["nvidia"];
  };

  # see https://wiki.archlinux.org/title/Hardware_video_acceleration#Verification
  environment.systemPackages = with pkgs; [
    libva-utils # for vainfo
    vdpauinfo # vdpauinfo
    vulkan-tools # vulkaninfo
    intel-gpu-tools # intel_gpu_top
    # nvtopPackages.full
  ];
}
