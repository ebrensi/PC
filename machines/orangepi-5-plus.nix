# Hardware configuration for the Orange Pi 5 Plus (Rockchip RK3588).
#
# Boot chain: mainline U-Boot lives in the board's SPI NOR flash (written once
#  over USB with `nix run .#tv-flash-spi`), finds the EFI system partition on
#  the NVMe drive, and hands off to systemd-boot. Everything on the drive is
#  ordinary NixOS, so it installs with `install-direct` like the laptops.
#
# The stock nixpkgs kernel covers this board: PCIe/NVMe, the VOP2 display
#  controller, HDMI (dw-hdmi-qp, with CEC), the Mali-G610 GPU (panthor), and the
#  hantro + rkvdec (VDPU381) video decoders all ship as modules or built-ins.
{
  config,
  lib,
  pkgs,
  ...
}: {
  nixpkgs.hostPlatform = "aarch64-linux";
  # base.nix defaults buildPlatform to x86_64, which would cross-compile the
  #  whole system and miss cache.nixos.org entirely. Build natively on m1.
  nixpkgs.buildPlatform = "aarch64-linux";

  boot = {
    # U-Boot implements enough UEFI to run systemd-boot, but it has no
    #  persistent EFI variable store.
    loader.efi.canTouchEfiVariables = lib.mkForce false;
    # Hand the kernel its own device tree instead of the copy built into
    #  U-Boot, so the kernel's DT always matches the kernel's drivers.
    loader.systemd-boot.installDeviceTree = true;
    loader.systemd-boot.configurationLimit = lib.mkDefault 5;

    initrd.availableKernelModules = ["nvme" "phy_rockchip_naneng_combphy" "usb_storage" "uas" "sd_mod"];
    # Serial console on the 3-pin debug header (1.5 Mbaud), plus the screen.
    kernelParams = ["console=ttyS2,1500000" "console=tty1"];
  };

  hardware = {
    deviceTree.enable = true;
    deviceTree.name = "rockchip/rk3588-orangepi-5-plus.dtb";
    # The RTC's open-drain INT line has no pull-up in the mainline DT, so it
    #  floats low and the level-low IRQ fires ~4k times/s (plus ~25k/s I2C
    #  interrupts from the handler polling the chip), all on CPU0.
    deviceTree.overlays = [
      {
        name = "hym8563-int-pull-up";
        dtsText = ''
          /dts-v1/;
          /plugin/;
          / { compatible = "xunlong,orangepi-5-plus"; };
          &hym8563_int { rockchip,pins = <0 8 0 &pcfg_pull_up>; };
        '';
      }
    ];
    # RTL8125 ethernet firmware, and whatever WiFi card is in the M.2 E-key slot
    enableRedistributableFirmware = true;
    graphics.enable = true;
  };

  # The 2.5G ethernet ports are the reliable link for a TV; WiFi is optional.
  networking.wireless.enable = false;
}
