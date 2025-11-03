# GPU Passthrough with Direct QEMU Commands

This guide shows how to use GPU passthrough with direct QEMU commands (without libvirt/virt-manager).

## Prerequisites

After enabling GPU passthrough in `machines/system76-adderws.nix` and rebooting, verify:

```bash
# GPU should be bound to vfio-pci
lspci -nnk -d 10de:28a1

# VFIO device should exist
ls -l /dev/vfio/11
```

## Basic QEMU Command with GPU Passthrough

Here's a minimal example to boot a VM with GPU passthrough:

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -M q35 \
  -m 8G \
  -smp 4 \
  -cpu host,kvm=off \
  -bios /run/libvirt/nix-ovmf/OVMF_CODE.fd \
  -device vfio-pci,host=01:00.0 \
  -device vfio-pci,host=01:00.1 \
  -drive file=/path/to/disk.qcow2,format=qcow2,if=virtio \
  -cdrom /path/to/installer.iso \
  -boot order=d
```

### Explanation of Key Parameters

- `-enable-kvm`: Use KVM acceleration
- `-M q35`: Use Q35 chipset (required for PCIe passthrough)
- `-m 8G`: 8GB RAM
- `-smp 4`: 4 CPU cores
- `-cpu host,kvm=off`: Pass through host CPU, hide KVM (helps avoid Nvidia Code 43)
- `-bios /run/libvirt/nix-ovmf/OVMF_CODE.fd`: UEFI firmware (required for GPU passthrough)
- `-device vfio-pci,host=01:00.0`: Pass through GPU (bus:slot.function)
- `-device vfio-pci,host=01:00.1`: Pass through GPU audio
- `-boot order=d`: Boot from CD-ROM first

## Creating a Disk Image

```bash
qemu-img create -f qcow2 /path/to/vm-disk.qcow2 60G
```

## More Complete Example

This includes networking, better display setup, and USB input:

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -M q35 \
  -m 8G \
  -smp 4,sockets=1,cores=4,threads=1 \
  -cpu host,kvm=off,hv_vendor_id=1234567890ab \
  -bios /run/libvirt/nix-ovmf/OVMF_CODE.fd \
  \
  `# GPU Passthrough` \
  -device vfio-pci,host=01:00.0,multifunction=on \
  -device vfio-pci,host=01:00.1 \
  \
  `# Disk` \
  -drive file=/var/lib/qemu/windows.qcow2,format=qcow2,if=virtio,cache=none \
  \
  `# Network` \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  \
  `# Virtual display for installation (can remove after GPU drivers installed)` \
  -vga qxl \
  -display gtk,gl=on \
  \
  `# USB input (allows host keyboard/mouse to control VM)` \
  -device qemu-xhci,id=xhci \
  -device usb-kbd,bus=xhci.0 \
  -device usb-tablet,bus=xhci.0 \
  \
  `# Install media` \
  -cdrom /path/to/installer.iso
```

After installing GPU drivers in the guest, you can:
1. Remove `-vga qxl -display gtk,gl=on`
2. Connect a physical monitor to the GPU
3. VM will only display on the physical monitor

## NixOS Declarative VM with GPU Passthrough

You can also define VMs declaratively in NixOS. Create a new file:

### `machines/vms/gaming-vm.nix`

```nix
{ config, pkgs, ... }:

{
  # This creates a systemd service to run the VM
  systemd.services.gaming-vm = {
    description = "Gaming VM with GPU Passthrough";
    # Don't auto-start, run manually with: systemctl start gaming-vm
    wantedBy = [ ];

    serviceConfig = {
      Type = "simple";
      ExecStart = let
        qemuCmd = pkgs.writeShellScript "start-gaming-vm" ''
          ${pkgs.qemu}/bin/qemu-system-x86_64 \
            -enable-kvm \
            -M q35 \
            -m 8G \
            -smp 4 \
            -cpu host,kvm=off,hv_vendor_id=1234567890ab \
            -drive if=pflash,format=raw,readonly=on,file=${pkgs.OVMF.fd}/FV/OVMF_CODE.fd \
            -drive if=pflash,format=raw,file=/var/lib/qemu/gaming-vm-efivars.fd \
            \
            -device vfio-pci,host=01:00.0,multifunction=on \
            -device vfio-pci,host=01:00.1 \
            \
            -drive file=/var/lib/qemu/gaming-vm.qcow2,format=qcow2,if=virtio,cache=none \
            \
            -netdev user,id=net0 \
            -device virtio-net-pci,netdev=net0 \
            \
            -vga qxl \
            -display gtk,gl=on \
            \
            -device qemu-xhci,id=xhci \
            -device usb-kbd,bus=xhci.0 \
            -device usb-tablet,bus=xhci.0
        '';
      in "${qemuCmd}";
      Restart = "no";
    };
  };

  # Create the disk image and EFI vars on first activation
  system.activationScripts.create-gaming-vm-disk = {
    text = ''
      if [ ! -f /var/lib/qemu/gaming-vm.qcow2 ]; then
        mkdir -p /var/lib/qemu
        ${pkgs.qemu}/bin/qemu-img create -f qcow2 /var/lib/qemu/gaming-vm.qcow2 60G
      fi
      if [ ! -f /var/lib/qemu/gaming-vm-efivars.fd ]; then
        cp ${pkgs.OVMF.fd}/FV/OVMF_VARS.fd /var/lib/qemu/gaming-vm-efivars.fd
        chmod 600 /var/lib/qemu/gaming-vm-efivars.fd
      fi
    '';
  };
}
```

Then import it in your configuration:

```nix
# In home-server.nix or system76-adderws.nix
imports = [
  ./machines/vms/gaming-vm.nix
];
```

Start the VM with:
```bash
sudo systemctl start gaming-vm
```

Stop with:
```bash
sudo systemctl stop gaming-vm
```

## Using NixOS `config.system.build.vm` for GPU Passthrough

You can also use the NixOS `.build.vm` approach, but you need to add QEMU flags. This works best for NixOS guests:

### `machines/vms/nixos-gpu-vm.nix`

```nix
# This is a complete NixOS system configuration
{ config, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
  ];

  # VM-specific settings
  virtualisation = {
    # Enable UEFI boot (required for GPU passthrough)
    useEFIBoot = true;

    qemu = {
      # Add GPU passthrough devices
      options = [
        "-device vfio-pci,host=01:00.0,multifunction=on"
        "-device vfio-pci,host=01:00.1"
        "-M q35"
        "-cpu host,kvm=off"
      ];
    };
    memorySize = 8192;
    cores = 4;
  };

  # Install NVIDIA drivers in the guest
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.open = false;  # Use proprietary drivers

  # ... rest of your NixOS config
  users.users.myuser = {
    isNormalUser = true;
    initialPassword = "changeme";
  };

  system.stateVersion = "24.05";
}
```

Build and run:
```bash
nixos-rebuild build-vm -I nixos-config=./machines/vms/nixos-gpu-vm.nix
./result/bin/run-*-vm
```

## Helper Script for Manual VM Management

Create a simple script to manage your QEMU VMs:

### `~/bin/start-gaming-vm.sh`

```bash
#!/usr/bin/env bash

VM_NAME="gaming-vm"
DISK="/var/lib/qemu/${VM_NAME}.qcow2"
ISO="${1:-}"  # Optional: pass installer ISO as first argument

# Create disk if it doesn't exist
if [ ! -f "$DISK" ]; then
  echo "Creating disk image..."
  qemu-img create -f qcow2 "$DISK" 80G
fi

# Build QEMU command
QEMU_ARGS=(
  -enable-kvm
  -M q35
  -m 8G
  -smp 4
  -cpu host,kvm=off,hv_vendor_id=1234567890ab
  -bios /run/libvirt/nix-ovmf/OVMF_CODE.fd

  # GPU Passthrough
  -device vfio-pci,host=01:00.0,multifunction=on
  -device vfio-pci,host=01:00.1

  # Disk
  -drive file="$DISK",format=qcow2,if=virtio,cache=none

  # Network
  -netdev user,id=net0
  -device virtio-net-pci,netdev=net0

  # Display
  -vga qxl
  -display gtk,gl=on

  # Input
  -device qemu-xhci,id=xhci
  -device usb-kbd,bus=xhci.0
  -device usb-tablet,bus=xhci.0
)

# Add ISO if provided
if [ -n "$ISO" ]; then
  QEMU_ARGS+=(-cdrom "$ISO")
fi

echo "Starting VM: $VM_NAME"
qemu-system-x86_64 "${QEMU_ARGS[@]}"
```

Make it executable and use:
```bash
chmod +x ~/bin/start-gaming-vm.sh

# First time (with installer)
~/bin/start-gaming-vm.sh /path/to/installer.iso

# Subsequent boots
~/bin/start-gaming-vm.sh
```

## Which Approach Should You Use?

- **Direct QEMU commands**: Maximum flexibility, closer to what you're used to with `.build.vm`
- **NixOS declarative VM**: Best for NixOS guests, fully declarative
- **libvirt/virt-manager**: Better for managing multiple VMs, nice GUI, persistent VM definitions
- **systemd service**: Middle ground - declarative but runs any guest OS

## Key Differences from `.build.vm`

The main difference from NixOS's `.build.vm`:

1. `.build.vm` is designed for **testing NixOS configurations** (typically NixOS guests)
2. GPU passthrough VMs often run **Windows or other Linux distros**
3. Direct QEMU or systemd services give you more control over the QEMU command line

For NixOS guests with GPU passthrough, you can definitely use the `.build.vm` approach with custom QEMU options as shown above!
