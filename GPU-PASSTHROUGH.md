# GPU Passthrough Configuration Guide

This guide explains how to use the NVIDIA RTX 4050 GPU with QEMU/KVM virtual machines on the System76 Adder WS.

## Quick Start

### Enable/Disable GPU Passthrough

The GPU passthrough is controlled by a NixOS module in `machines/system76-adderws.nix`:

```nix
virtualisation.gpuPassthrough = {
  enable = true;  # Set to false to use GPU on host instead
  pciIds = [
    "10de:28a1"  # GeForce RTX 4050 Max-Q
    "10de:22be"  # NVIDIA Audio Controller
  ];
};
```

After changing this setting, rebuild and reboot:
```bash
sudo nixos-rebuild switch --flake .#adder-ws
sudo reboot
```

## Verify GPU Passthrough is Active

After reboot, verify the GPU is bound to VFIO:

```bash
# Check GPU driver
lspci -nnk -d 10de:28a1

# Should show:
#   Kernel driver in use: vfio-pci
```

Check available VFIO devices:
```bash
ls -l /dev/vfio/
# Should show: /dev/vfio/11 (IOMMU group number)
```

## Configure VM with GPU Access

### Option 1: Using virt-manager (GUI)

1. **Open virt-manager**
   ```bash
   virt-manager
   ```

2. **Create a new VM or edit existing VM:**
   - Right-click on VM → "Open" or "Show virtual hardware details"

3. **Configure firmware (REQUIRED for GPU passthrough):**
   - Click "Overview" in left sidebar
   - Firmware: Select `UEFI x86_64: /run/libvirt/nix-ovmf/OVMF_CODE.fd`
   - Chipset: `Q35`

4. **Add GPU to VM:**
   - Click "Add Hardware" button
   - Select "PCI Host Device"
   - Find and add: `0000:01:00.0 NVIDIA Corporation AD107M [GeForce RTX 4050]`
   - Click "Finish"

5. **Add GPU Audio (optional but recommended):**
   - Click "Add Hardware" again
   - Select "PCI Host Device"
   - Find and add: `0000:01:00.1 NVIDIA Corporation AD107 HD Audio`
   - Click "Finish"

6. **Configure display:**

   For initial setup, keep the virtual display (Spice/QXL):
   - This lets you see BIOS and boot process
   - After installing GPU drivers in the guest, you can switch to GPU-only

   For GPU-only display:
   - Remove the Spice display and QXL video
   - Connect a physical monitor to the GPU output
   - VM will only output to the physical display

7. **Start the VM**

### Option 2: Using virsh/XML (Command Line)

1. **Create or edit VM XML:**
   ```bash
   virsh edit your-vm-name
   ```

2. **Ensure UEFI firmware and Q35 chipset:**
   ```xml
   <os>
     <type arch='x86_64' machine='pc-q35-8.2'>hvm</type>
     <loader readonly='yes' type='pflash'>/run/libvirt/nix-ovmf/OVMF_CODE.fd</loader>
     <nvram>/var/lib/libvirt/qemu/nvram/your-vm-name_VARS.fd</nvram>
     <boot dev='hd'/>
   </os>
   ```

3. **Add GPU PCI devices:**
   ```xml
   <devices>
     <!-- GPU -->
     <hostdev mode='subsystem' type='pci' managed='yes'>
       <source>
         <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
       </source>
       <address type='pci' domain='0x0000' bus='0x05' slot='0x00' function='0x0'/>
     </hostdev>

     <!-- GPU Audio -->
     <hostdev mode='subsystem' type='pci' managed='yes'>
       <source>
         <address domain='0x0000' bus='0x01' slot='0x00' function='0x1'/>
       </source>
       <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
     </hostdev>

     <!-- Keep virtual display for initial setup -->
     <graphics type='spice' autoport='yes'>
       <listen type='address'/>
     </graphics>
     <video>
       <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1'/>
       <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x0'/>
     </video>
   </devices>
   ```

4. **Start the VM:**
   ```bash
   virsh start your-vm-name
   ```

## Inside the Guest OS

### For Linux Guests

1. **Install NVIDIA drivers:**
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install nvidia-driver-550

   # Fedora
   sudo dnf install akmod-nvidia
   ```

2. **Verify GPU is detected:**
   ```bash
   lspci | grep -i nvidia
   nvidia-smi
   ```

### For Windows Guests

1. **Boot Windows VM**
2. **Install NVIDIA drivers:**
   - Download latest drivers from nvidia.com
   - Or let Windows Update install them
3. **Verify in Device Manager:**
   - Should see "NVIDIA GeForce RTX 4050" without errors
4. **Test with nvidia-smi or a game**

## Common Issues and Solutions

### Issue: VM won't start with GPU attached

**Solution:** Ensure UEFI firmware is selected (not legacy BIOS)
```xml
<loader readonly='yes' type='pflash'>/run/libvirt/nix-ovmf/OVMF_CODE.fd</loader>
```

### Issue: Code 43 Error in Windows Device Manager

**Solutions:**
1. Hide virtualization from guest (add to VM XML):
   ```xml
   <features>
     <hyperv>
       <vendor_id state='on' value='1234567890ab'/>
     </hyperv>
     <kvm>
       <hidden state='on'/>
     </kvm>
   </features>
   ```

2. Ensure both GPU and Audio are passed through

### Issue: Black screen on boot

**Solution:** Keep the virtual display (Spice/QXL) until GPU drivers are installed in guest

### Issue: GPU not showing in guest

**Verify on host:**
```bash
lspci -nnk -d 10de:28a1
# Must show: Kernel driver in use: vfio-pci

# Check VFIO device exists
ls -l /dev/vfio/
```

## VM Creation Example (Complete)

Here's a complete example using virt-install:

```bash
virt-install \
  --name windows-gpu \
  --memory 8192 \
  --vcpus 4 \
  --disk path=/var/lib/libvirt/images/windows-gpu.qcow2,size=60 \
  --os-variant win11 \
  --network network=default \
  --graphics spice \
  --video qxl \
  --boot uefi \
  --machine q35 \
  --hostdev 0000:01:00.0 \
  --hostdev 0000:01:00.1 \
  --cdrom /path/to/windows.iso
```

For Linux VM, similar but change `--os-variant`:
```bash
virt-install \
  --name ubuntu-gpu \
  --memory 8192 \
  --vcpus 4 \
  --disk path=/var/lib/libvirt/images/ubuntu-gpu.qcow2,size=60 \
  --os-variant ubuntu22.04 \
  --network network=default \
  --graphics spice \
  --video qxl \
  --boot uefi \
  --machine q35 \
  --hostdev 0000:01:00.0 \
  --hostdev 0000:01:00.1 \
  --cdrom /path/to/ubuntu.iso
```

## VMs Without GPU

VMs that don't need GPU access can be created normally without adding the PCI devices. They won't use the GPU, and the GPU will remain reserved but unused.

## Performance Tips

1. **CPU Pinning:** Pin VM vCPUs to physical cores for better performance
2. **Huge Pages:** Enable huge pages for lower memory latency
3. **CPU Mode:** Use `host-passthrough` for best CPU performance
4. **Disk:** Use virtio-scsi with cache='none' for best I/O performance

## Switching Back to Host GPU Usage

To use the GPU on the host instead of VMs:

1. Edit `machines/system76-adderws.nix`:
   ```nix
   virtualisation.gpuPassthrough = {
     enable = false;  # Disable passthrough
     # ... pciIds remain for reference
   };
   ```

2. Rebuild and reboot:
   ```bash
   sudo nixos-rebuild switch --flake .#adder-ws
   sudo reboot
   ```

3. Verify NVIDIA drivers loaded:
   ```bash
   nvidia-smi
   ```

## Additional Resources

- [Arch Linux PCI Passthrough Guide](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [VFIO Discussion Forum](https://www.reddit.com/r/VFIO/)
- [GPU Passthrough on NixOS](https://nixos.wiki/wiki/VFIO_PCI_Passthrough)
