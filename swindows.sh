#!/bin/bash
# swap-OS (swindows)

# --- 1. PRE-FLIGHT CHECKS ---

# Check 1: Root Privileges
if [[ $EUID -ne 0 ]]; then
  echo "Error: This application requires root privileges. Please use \"sudo\""
  exit 1
fi

# Check 2: Dependency Check
for cmd in efibootmgr systemctl findmnt grep; do
  if ! command -v $cmd &>/dev/null; then
    echo "Error: Required command '$cmd' is not installed."
    exit 1
  fi
done

# Check 3: Hibernation Capability (Kernel Support)
if ! grep -q "disk" /sys/power/state; then
  echo "Error: Your kernel does not support hibernation."
  echo "Please ensure you have a swap file/partition and resume hooks configured."
  exit 1
fi

# Check 4: Resume Configuration (Bootloader Args)
if ! grep -q "resume=" /proc/cmdline; then
  echo "Error: Hibernation parameters missing in bootloader."
  echo "The 'resume=UUID=...' argument was not found in /proc/cmdline."
  echo "You MUST configure your bootloader (Grub/Systemd-boot) before using this app."
  exit 1
fi

# --- 2. WINDOWS DETECTION ---

# Find Windows Boot Manager ID (Case insensitive)
WIN_ID=$(efibootmgr | grep -i "Windows Boot Manager" | grep -oP 'Boot\K[0-9A-F]+' | head -n 1)

if [ -z "$WIN_ID" ]; then
  echo "Error: Windows Boot Manager not found in UEFI entries."
  echo "Is Windows installed in UEFI mode?"
  exit 1
fi

echo "✓ Windows Boot Manager detected at ID: $WIN_ID"

# --- 3. FILESYSTEM SAFETY ---

echo "Performing filesystem safety checks..."

# Unmount Windows/NTFS partitions to prevent corruption
MOUNTED_WINDOWS=$(findmnt -rn -o TARGET -t fuseblk,ntfs,ntfs3)

if [ -n "$MOUNTED_WINDOWS" ]; then
  echo "Warning: Detected mounted Windows partition(s):"
  echo "$MOUNTED_WINDOWS"
  echo "Unmounting..."

  for mount_point in $MOUNTED_WINDOWS; do
    umount "$mount_point"
    if [ $? -eq 0 ]; then
      echo "✓ Successfully unmounted $mount_point"
    else
      echo "Error: Could not unmount $mount_point."
      echo "Please close applications using Windows drives and try again."
      exit 1
    fi
  done
else
  echo "No active Windows partitions detected."
fi

# --- 4. EXECUTION ---

echo "Setting next boot target to Windows..."
efibootmgr --bootnext "$WIN_ID" &>/dev/null

if [ $? -ne 0 ]; then
  echo "Error: Failed to set BootNext flag via efibootmgr."
  exit 1
fi

echo "Success. System is going down for hibernation..."
sleep 1

systemctl hibernate

echo "Welcome back to Linux."
