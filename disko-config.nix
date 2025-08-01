# disko-config.nix - Declarative disk partitioning for System76 Adder
# This configuration creates a modern UEFI setup with LUKS encryption and Btrfs
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1"; # Adjust this to your actual NVMe device
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00"; # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "umask=0077" # Secure boot partition
                ];
              };
            };

            # Optional: separate /boot partition for better security
            boot = {
              size = "1G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot/nixos";
              };
            };

            # LUKS encrypted root partition
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                # Prompt for password during installation
                passwordFile = "/tmp/secret.key"; # You'll create this during install
                settings = {
                  allowDiscards = true; # Good for SSD performance
                  bypassWorkqueues = true; # Performance improvement
                };
                # Use strong encryption
                extraOpenArgs = [
                  "--cipher"
                  "aes-xts-plain64"
                  "--key-size"
                  "512"
                  "--hash"
                  "sha512"
                ];
                content = {
                  type = "btrfs";
                  extraArgs = ["-L" "nixos" "-f"]; # Force and label
                  subvolumes = {
                    # Root subvolume
                    "/root" = {
                      mountpoint = "/";
                      mountOptions = ["compress=zstd" "noatime"];
                    };

                    # Home subvolume (separate for easy backup/restore)
                    "/home" = {
                      mountpoint = "/home";
                      mountOptions = ["compress=zstd" "noatime"];
                    };

                    # Nix store subvolume (no COW for better performance)
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = ["compress=zstd" "noatime" "nodatacow"];
                    };

                    # Persistent system state
                    "/persist" = {
                      mountpoint = "/persist";
                      mountOptions = ["compress=zstd" "noatime"];
                    };

                    # Swap subvolume (for swapfile)
                    "/swap" = {
                      mountpoint = "/swap";
                      mountOptions = ["noatime" "nodatacow"];
                    };

                    # Snapshots subvolume (excluded from snapshots)
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

    # Create swapfile on btrfs
    nodev = {
      "/swap/swapfile" = {
        fsType = "none";
        device = "none";
        options = [
          "bind"
        ];
      };
    };
  };

  # Swapfile configuration
  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 32 * 1024; # 32GB swap (adjust based on your RAM)
    }
  ];
}
