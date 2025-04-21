# USB Mode Changer Script

## Overview
This script automates the process of changing the USB mode from "peripheral" to "host" on ARM64 devices running Kali Linux, specifically for Qualcomm's sdm845 platform (like OnePlus 6). This enables USB OTG (On-The-Go) functionality, allowing you to connect USB devices to your phone.

## Background
Mobile devices typically operate in "peripheral" USB mode, which means they act as a device when connected to a computer. By modifying the Device Tree Blob (DTB) to use "host" mode instead, the device can power and communicate with external USB peripherals like keyboards, mice, flash drives, and more.

## What the Script Does
1. Extracts the Device Tree Blob (DTB) for your device
2. Converts the DTB to a readable text format (DTS)
3. Modifies the USB mode from "peripheral" to "host"
4. Converts the modified DTS back to DTB format
5. Combines this DTB with your kernel
6. Creates a new boot image with the modified kernel
7. Optionally flashes the new boot image to your device

## Requirements
- Kali Linux on an ARM64 device (sdm845 platform)
- Root privileges
- The following packages (automatically installed by the script):
  - device-tree-compiler
  - abootimg

## Usage

### Basic Usage
```bash
sudo ./usb_host_mode.sh
```
This will run the script in interactive mode, prompting you to select the boot partition.

### Command-line Options
```bash
sudo ./usb_host_mode.sh -d DTB_SOURCE -k KERNEL_PATH -b BOOT_SLOT
```

- `-d DTB_SOURCE`: Path to the source DTB file (default: "/lib/linux-image-6.6-sdm845/qcom/sdm845-oneplus-enchilada.dtb")
- `-k KERNEL_PATH`: Path to the kernel file (default: "/boot/vmlinuz-6.6-sdm845")
- `-b BOOT_SLOT`: Boot partition slot (a, b, or 0 for no suffix)
- `-h`: Display help message

### Examples

#### For devices with A/B partitioning scheme (boot_a and boot_b)
```bash
# Modify boot_a partition
sudo ./usb_host_mode.sh -b a

# Modify boot_b partition
sudo ./usb_host_mode.sh -b b
```

#### For devices with a single boot partition (no suffix)
```bash
sudo ./usb_host_mode.sh -b 0
```

#### With custom paths
```bash
sudo ./usb_host_mode.sh -d /path/to/custom.dtb -k /path/to/custom/kernel -b a
```

## Common Use Cases

### OnePlus 6 (enchilada)
```bash
sudo ./usb_host_mode.sh -b a
```

### Custom ROM with Different Kernel Path
```bash
sudo ./usb_host_mode.sh -k /boot/vmlinuz-custom -b a
```

### Different Device with Same Platform
```bash
sudo ./usb_host_mode.sh -d /lib/linux-image-6.6-sdm845/qcom/sdm845-different-device.dtb -b 0
```

## Restoring Original Configuration
The script creates a backup of your original boot image as `original_boot_[slot].img` in the `/tmp/dtb_mod/` directory. If you need to restore the original configuration:

```bash
# For boot_a partition
sudo dd if=/tmp/dtb_mod/original_boot_a.img of=/dev/disk/by-partlabel/boot_a bs=4M
sudo sync
sudo reboot

# For boot partition (no suffix)
sudo dd if=/tmp/dtb_mod/original_boot_standard.img of=/dev/disk/by-partlabel/boot bs=4M
sudo sync
sudo reboot
```

## Troubleshooting

### Script fails to find DTB or kernel
Double-check the paths for your specific device:
1. Find your device's DTB: `find /lib -name "*.dtb" | grep your_device_name`
2. Find your kernel: `ls -l /boot/vmlinuz*`

### Device doesn't boot after flashing
Restore the original boot image using the backup created by the script, or boot into your recovery image and restore from there.

### USB host mode isn't working
Some devices might require additional configuration. Make sure to:
1. Connect an OTG adapter if necessary
2. Ensure your device has enough power (consider using a powered USB hub)
3. Check if your device has hardware limitations preventing USB host mode

## Caution
Modifying boot images can potentially brick your device if done incorrectly. Always ensure you have:
1. A working backup of your boot partition
2. A way to restore your device (like TWRP recovery)
3. Knowledge of how to use fastboot in case of boot failures

## License
This script is provided as-is under the MIT License.
