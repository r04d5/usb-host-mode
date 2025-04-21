#!/bin/bash

# Script to automate USB mode conversion from peripheral to host
# For Kali Linux on sdm845 devices (OnePlus 6)
# With support for boot partition flags

# Default values
DTB_SOURCE="/lib/linux-image-6.6-sdm845/qcom/sdm845-oneplus-enchilada.dtb"
KERNEL_PATH="/boot/vmlinuz-6.6-sdm845"
BOOT_PARTITION=""
BOOT_SLOT=""
WORK_DIR="/tmp/dtb_mod"

# Function to display usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -d DTB_SOURCE    Path to the source DTB file"
    echo "  -k KERNEL_PATH   Path to the kernel file"
    echo "  -b BOOT_SLOT     Boot partition slot (a, b, or 0 for no suffix)"
    echo "  -h               Display this help message"
    echo ""
    echo "Example:"
    echo "  $0 -d /path/to/dtb -k /path/to/kernel -b a"
    exit 1
}

# Parse command line arguments
while getopts "d:k:b:h" opt; do
    case ${opt} in
        d)
            DTB_SOURCE=${OPTARG}
            ;;
        k)
            KERNEL_PATH=${OPTARG}
            ;;
        b)
            if [[ ${OPTARG} == "a" ]]; then
                BOOT_PARTITION="/dev/disk/by-partlabel/boot_a"
                BOOT_SLOT="a"
            elif [[ ${OPTARG} == "b" ]]; then
                BOOT_PARTITION="/dev/disk/by-partlabel/boot_b"
                BOOT_SLOT="b"
            elif [[ ${OPTARG} == "0" ]]; then
                BOOT_PARTITION="/dev/disk/by-partlabel/boot"
                BOOT_SLOT="standard"
            else
                echo "Invalid boot slot: ${OPTARG}. Use 'a', 'b', or '0'"
                usage
            fi
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option: ${OPTARG}"
            usage
            ;;
    esac
done

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi

# If no boot partition was specified, prompt the user
if [ -z "$BOOT_PARTITION" ]; then
    echo "Select boot partition to modify:"
    echo "1) boot_a"
    echo "2) boot_b"
    echo "3) boot (no suffix)"
    
    read -p "Option: " boot_option
    
    case $boot_option in
        1)
            BOOT_PARTITION="/dev/disk/by-partlabel/boot_a"
            BOOT_SLOT="a"
            ;;
        2)
            BOOT_PARTITION="/dev/disk/by-partlabel/boot_b"
            BOOT_SLOT="b"
            ;;
        3)
            BOOT_PARTITION="/dev/disk/by-partlabel/boot"
            BOOT_SLOT="standard"
            ;;
        *)
            echo "Invalid option. Exiting."
            exit 1
            ;;
    esac
fi

# Check if the necessary files exist
if [ ! -e "$DTB_SOURCE" ]; then
    echo "[!] DTB file not found: $DTB_SOURCE"
    read -p "Enter the correct path to the DTB file: " DTB_SOURCE
    if [ ! -e "$DTB_SOURCE" ]; then
        echo "[!] DTB file not found. Aborting."
        exit 1
    fi
fi

if [ ! -e "$KERNEL_PATH" ]; then
    echo "[!] Kernel file not found: $KERNEL_PATH"
    read -p "Enter the correct path to the kernel: " KERNEL_PATH
    if [ ! -e "$KERNEL_PATH" ]; then
        echo "[!] Kernel file not found. Aborting."
        exit 1
    fi
fi

if [ ! -e "$BOOT_PARTITION" ]; then
    echo "[!] The specified boot partition does not exist: $BOOT_PARTITION"
    exit 1
fi

# Create working directory
echo "[+] Creating working directory..."
mkdir -p $WORK_DIR
cd $WORK_DIR

# Install required dependencies
echo "[+] Installing dependencies..."
apt install -y device-tree-compiler abootimg

# Copy original DTB
echo "[+] Copying original DTB..."
cp $DTB_SOURCE ./original.dtb
if [ $? -ne 0 ]; then
    echo "[!] Error copying original DTB. Check the path: $DTB_SOURCE"
    exit 1
fi

# Convert DTB to DTS
echo "[+] Converting DTB to DTS..."
dtc -o device.dts original.dtb
if [ $? -ne 0 ]; then
    echo "[!] Error converting DTB to DTS"
    exit 1
fi

# Check if the mode is peripheral
echo "[+] Checking current USB mode..."
if grep -q 'dr_mode = "peripheral"' device.dts; then
    echo "[+] Current USB mode: peripheral"
    
    # Modify mode from peripheral to host
    echo "[+] Changing USB mode to host..."
    sed -i 's/dr_mode = "peripheral"/dr_mode = "host"/g' device.dts
    
    # Verify if the change was successful
    if grep -q 'dr_mode = "host"' device.dts; then
        echo "[+] USB mode successfully changed to host"
    else
        echo "[!] Failed to change USB mode"
        exit 1
    fi
else
    echo "[!] USB mode 'peripheral' not found in DTS file"
    if grep -q 'dr_mode = "host"' device.dts; then
        echo "[+] USB mode is already set to host"
    else
        echo "[!] Unrecognized USB mode pattern"
        exit 1
    fi
fi

# Convert modified DTS back to DTB
echo "[+] Converting modified DTS back to DTB..."
dtc -o host.dtb device.dts
if [ $? -ne 0 ]; then
    echo "[!] Error converting DTS to DTB"
    exit 1
fi

# Combine kernel with modified DTB
echo "[+] Combining kernel with modified DTB..."
cat $KERNEL_PATH host.dtb > kernel.dtb
if [ $? -ne 0 ]; then
    echo "[!] Error combining kernel with DTB"
    exit 1
fi

# Backup current boot image
echo "[+] Backing up current boot image (slot $BOOT_SLOT)..."
dd if=$BOOT_PARTITION of=original_boot_${BOOT_SLOT}.img bs=4M
if [ $? -ne 0 ]; then
    echo "[!] Error backing up boot image"
    exit 1
fi

# Update boot image with modified kernel
echo "[+] Updating boot image with modified kernel..."
cp original_boot_${BOOT_SLOT}.img boot.img
abootimg -u boot.img -k kernel.dtb
if [ $? -ne 0 ]; then
    echo "[!] Error updating boot image"
    exit 1
fi

# Save modified image as host_boot.img
cp boot.img host_boot_${BOOT_SLOT}.img

# Ask user if they want to flash immediately
echo ""
echo "Modified boot image created as $WORK_DIR/host_boot_${BOOT_SLOT}.img"
read -p "Do you want to flash the new boot image to the selected partition now? (y/n): " FLASH_NOW

if [[ "$FLASH_NOW" =~ ^[Yy]$ ]]; then
    echo "[+] Flashing new boot image to partition $BOOT_PARTITION..."
    dd if=host_boot_${BOOT_SLOT}.img of=$BOOT_PARTITION bs=4M
    if [ $? -ne 0 ]; then
        echo "[!] Error flashing boot image"
        exit 1
    fi
    
    echo "[+] Running sync to ensure all changes are written..."
    sync
    
    echo "[+] Process completed successfully!"
    read -p "Do you want to reboot the device now? (y/n): " REBOOT_NOW
    if [[ "$REBOOT_NOW" =~ ^[Yy]$ ]]; then
        echo "[+] Rebooting device in 5 seconds..."
        sleep 5
        reboot
    else
        echo "[+] Remember to reboot manually to apply changes."
    fi
else
    echo "[+] Modified boot image saved at: $WORK_DIR/host_boot_${BOOT_SLOT}.img"
    echo "[+] To flash manually, run:"
    echo "    dd if=$WORK_DIR/host_boot_${BOOT_SLOT}.img of=$BOOT_PARTITION bs=4M"
    echo "    sync"
    echo "    reboot"
fi

exit 0