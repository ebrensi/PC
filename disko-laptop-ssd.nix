# disko-config-simple.nix - Simple disk configuration without encryption
# Use this if you prefer a simpler setup without LUKS encryption
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1"; # Adjust to your actual NVMe device
        content = {
          type = "gpt";
          partitions = {
            # EFI System Partition
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "umask=0077"
                ];
              };
            };

            # Root partition with Btrfs
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-L" "nixos" "-f"];
                subvolumes = {
                  # Root subvolume
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = ["compress=zstd" "noatime"];
                  };

                  # Home subvolume
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = ["compress=zstd" "noatime"];
                  };

                  # Nix store (no COW for performance)
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = ["compress=zstd" "noatime" "nodatacow"];
                  };

                  # Swap subvolume
                  "/swap" = {
                    mountpoint = "/swap";
                    mountOptions = ["noatime" "nodatacow"];
                  };

                  # Snapshots
                  "/snapshots" = {
                    mountpoint = "/snapshots";
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

  # Swapfile configuration
  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 16 * 1024; # 16GB swap (adjust for your system)
    }
  ];
}
