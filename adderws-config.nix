# Configuration Specific to System76 Adder WS Laptop WorkStation
{
  config,
  lib,
  pkgs,
  nixos-hardware,
  ...
}: {
  # hardware profiles from nixos-hardware
  imports = with nixos-hardware.nixosModules; [
    system76
    common-cpu-intel
    common-gpu-intel
    # common-gpu-nvidia # (GPU Offload mode)
    common-gpu-nvidia-sync # (GPU Sync mode)
    common-pc-ssd
    common-pc-laptop
    common-hidpi
    ./adderws.hardware.nix # From hardware scan
  ];

  # see https://wiki.archlinux.org/title/Hardware_video_acceleration#Verification
  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
    libva-utils # for vainfo
    vdpauinfo # vdpauinfo
    vulkan-tools # vulkaninfo
    intel-gpu-tools # intel_gpu_top
  ];

  hardware.enableRedistributableFirmware = true;
  hardware.firmware = [pkgs.linux-firmware];
  hardware.nvidia = {
    open = true;
    nvidiaSettings = true;
    prime = {
      nvidiaBusId = "PCI:1:0:0";
      intelBusId = "PCI:0:2:0";
    };
  };
  hardware.nvidia-container-toolkit.enable = true;
  hardware.graphics.extraPackages = [
    pkgs.intel-compute-runtime # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-opencl-intel
    pkgs.intel-media-driver # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-va-api-intel
    pkgs.vpl-gpu-rt # https://wiki.nixos.org/wiki/Intel_Graphics
  ];

  # See https://support.system76.com/articles/system76-software/
  services.power-profiles-daemon.enable = false;

  # This is a laptop machine acting as a server so we don't want it to sleep
  # When hooked to a dock or external power
  services.logind.settings.Login = {
    # Dont sleep when lid is closed on external power
    HandleLidSwitchExternalPower = "ignore";
    # Dont sleep when lid is closed we are connected to a docking station
    HandleLidSwitchDocked = "ignore";
  };
}
