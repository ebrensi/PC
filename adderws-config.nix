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
    ./disko-laptop-ssd.nix # Disk formatting
    ./adderws.hardware.nix # From hardware scan
  ];

  boot = {
    initrd.availableKernelModules = ["xhci_pci" "nvme" "thunderbolt" "uas" "sd_mod" "sdhci_pci"];
    initrd.kernelModules = [];
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
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

    # This is a laptop machine acting as a server so we don't want it to sleep
    # When hooked to a dock or external power
    logind.settings.Login = {
      # Dont sleep when lid is closed on external power
      HandleLidSwitchExternalPower = "ignore";
      # Dont sleep when lid is closed we are connected to a docking station
      HandleLidSwitchDocked = "ignore";
    };
  };

  # see https://wiki.archlinux.org/title/Hardware_video_acceleration#Verification
  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
    libva-utils # for vainfo
    vdpauinfo # vdpauinfo
    vulkan-tools # vulkaninfo
    intel-gpu-tools # intel_gpu_top
  ];
}
