# Lenovo ThinkPad X1 11th Gen
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

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  boot = {
    initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme"];
    initrd.kernelModules = ["i915"];
    kernelModules = ["kvm-intel" "iwlwifi"];
    extraModulePackages = [];
    # Force probe for 11th gen Intel GPU
    kernelParams = ["i915.force_probe=a7a1"];
  };

  # SSD optimization
  services.fstrim.enable = true;

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # ThinkPad TrackPoint
    trackpoint.enable = true;
    trackpoint.emulateWheel = true;

    # Graphics
    graphics.enable = true;
    # NOTE: Intel GPU packages commented out - may cause system crashes.
    # Uncomment if VAAPI is needed and system is stable:
    graphics.extraPackages = with pkgs; [
      intel-media-driver # VAAPI for hardware video decoding
      vpl-gpu-rt # Intel Video Processing Library
    ];
  };

  # GPU diagnostic tools
  environment.systemPackages = with pkgs; [
    libva-utils # vainfo command to verify VAAPI
    intel-gpu-tools # intel_gpu_top to monitor GPU usage
    nvtopPackages.intel
  ];
}
