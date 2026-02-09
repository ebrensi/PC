# Disko configuration for USB NVMe SSD (SanDisk Extreme Pro)
# Used for Docker storage and secondary nix store on m1
#
# To apply this configuration:
#   1. Ensure the drive is unmounted
#   2. Run: sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko-usb-nvme.nix
#
# Device identification: /dev/disk/by-id/usb-SanDisk_Extreme_Pro_55AF_323431364133343031333933-0:0
{
  disko.devices = {
    disk = {
      usb-nvme = {
        type = "disk";
        device = "/dev/disk/by-id/usb-SanDisk_Extreme_Pro_55AF_323431364133343031333933-0:0";
        content = {
          type = "gpt";
          partitions = {
            main = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f" "-L" "usb-nvme"];
                subvolumes = {
                  "@docker" = {
                    mountpoint = "/var/lib/docker";
                    mountOptions = ["compress=zstd" "noatime" "nodatacow"];
                  };
                  "@nix-alt" = {
                    mountpoint = "/mnt/nix-alt";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "@data" = {
                    mountpoint = "/mnt/usb-nvme";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
