{
  config,
  lib,
  pkgs,
  ...
}: {

    nixpkgs.config.allowUnfree = true;
    hardware.graphics.enable = true;
    services.xserver.videoDrivers = ["modesetting" "nvidia"];
    hardware.nvidia-container-toolkit.enable = true;

    hardware.nvidia = {
      modesetting.enable = true;

      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
      # Enable this if you have graphical corruption issues or application crashes after waking
      # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
      # of just the bare essentials.
      powerManagement.enable = false;

      # Fine-grained power management. Turns off GPU when not in use.
      # Experimental and only works on modern Nvidia GPUs (Turing or newer).
      powerManagement.finegrained = false;

      # Use the NVidia open source kernel module (not to be confused with the
      # independent third-party "nouveau" open source driver).
      # Support is limited to the Turing and later architectures. Full list of
      # supported GPUs is at:
      # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
      # Only available from driver 515.43.04+
      # Currently alpha-quality/buggy, so false is currently the recommended setting.
      open = true;

      # Enable the Nvidia settings menu,
      # accessible via `nvidia-settings`.
      nvidiaSettings = true;

      # This sometimes causes builds to fail so we disable it if yiu don't need it.
      package = config.boot.kernelPackages.nvidiaPackages.latest;

      prime = {
        sync.enable = true;
        # offload.enable = true;
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
    };

    # Install nvtop for monitoring GPU usage
    environment.systemPackages = [
      pkgs.nvtopPackages.nvidia
    ];
}
