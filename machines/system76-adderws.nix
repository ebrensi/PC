# Configuration Specific to System76 Adder WS Laptop WorkStation
# Hardware config inlined (no nixos-hardware dependency)
{
  config,
  lib,
  pkgs,
  modulesPath,
  #
  pkgs-stable,
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
      # finegrained = true causes the GPU to enter D3cold during idle and get
      # permanently stuck (nvidia-smi "Unknown Error", ollama GPU discovery timeout)
      # after ~21h idle. Regression with open modules + kernel 6.18.x.
      powerManagement.finegrained = false;
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
    # Separate launcher for Chrome using the NVIDIA dGPU via PRIME offload.
    # Uses makeDesktopItem so it lands in XDG_DATA_DIRS (share/applications/),
    # which is what COSMIC's app launcher actually searches.
    (pkgs.makeDesktopItem {
      name = "google-chrome-nvidia";
      desktopName = "Google Chrome (NVIDIA dGPU)";
      comment = "Access the Internet (NVIDIA dGPU)";
      exec = "env __NV_PRIME_RENDER_OFFLOAD=1 __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 __GLX_VENDOR_LIBRARY_NAME=nvidia __EGL_VENDOR_LIBRARY_FILENAMES=${config.hardware.nvidia.package}/share/glvnd/egl_vendor.d/10_nvidia.json /run/current-system/sw/bin/google-chrome-stable --render-node-override=/dev/dri/renderD129 %U";
      icon = "google-chrome";
      categories = ["Network" "WebBrowser"];
      mimeTypes = ["text/html" "text/xml" "application/xhtml+xml" "x-scheme-handler/http" "x-scheme-handler/https"];
      startupNotify = true;
      startupWMClass = "Google-chrome";
      keywords = ["Internet" "WWW" "Browser" "Web"];
    })
    libva-utils # for vainfo
    vdpauinfo # vdpauinfo
    vulkan-tools # vulkaninfo
    intel-gpu-tools # intel_gpu_top
    nvitop
    pkgs-stable.nvtopPackages.full
  ];
}
