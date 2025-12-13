#!/bin/bash
# swap-OS

# --- 1.CHECKS ---

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

# Check 3: Hibernation Capability
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

# --- 2. OS SELECTION ---

echo "--- Available Boot Entries ---"
# List entries
efibootmgr | grep -E "^Boot[0-9]{4}" | sed 's/\*//'

echo ""
read -p "Enter the boot number (e.g. 0002) or name (e.g. Windows): " USER_INPUT

# Ensure the input is not blank
if [ -z "$USER_INPUT" ]; then
  echo "Error: No input provided."
  exit 1
fi

# Find the ID based on user input
if [[ "$USER_INPUT" =~ ^[0-9A-Fa-f]{4}$ ]]; then
  TARGET_ID="$USER_INPUT"
else
  TARGET_ID=$(efibootmgr | grep -i "$USER_INPUT" | grep -oP 'Boot\K[0-9A-F]+' | head -n 1)
fi

# Validation
if [ -z "$TARGET_ID" ]; then
  echo "Error: Could not find a boot ID for input '$USER_INPUT'."
  exit 1
fi

echo "Boot ID detected: $TARGET_ID"

# --- 3. FILESYSTEM SAFETY ---

echo "Performing filesystem safety checks..."

# Filesystems to check
FS_TYPES="fuseblk,ntfs,ntfs3,ext4,btrfs,xfs,vfat,exfat"

# Filters out the root and system directories
MOUNTED_TARGETS=$(findmnt -rn -o TARGET -t "$FS_TYPES" | grep -vE '^/($|boot|efi|dev|proc|sys|run|tmp|var|home|usr|opt|srv)')

if [ -n "$MOUNTED_TARGETS" ]; then
  echo "Warning: Detected mounted shared partition(s):"
  echo "$MOUNTED_TARGETS"
  echo "Unmounting to prevent data corruption..."

  # Convert newlines to spaces for the loop
  IFS=$'\n'
  for mount_point in $MOUNTED_TARGETS; do
    # Attempt unmount
    umount "$mount_point"
    if [ $? -eq 0 ]; then
      echo "Successfully unmounted $mount_point"
    else
      echo "Error: Could not unmount $mount_point."
      echo "Please close applications using this drive and try again."
      # Reset IFS before exiting
      unset IFS
      exit 1
    fi
  done
  unset IFS
else
  echo "No risky partitions detected."
fi

# --- 4. EXECUTION ---

echo "Setting next boot target to ID $TARGET_ID..."
efibootmgr --bootnext "$TARGET_ID" &>/dev/null

if [ $? -ne 0 ]; then
  echo "Error: Failed to set BootNext flag via efibootmgr."
  exit 1
fi

echo "Success. System is going down for hibernation..."
sleep 1

systemctl hibernate

# --- 5. WAKE UP & ERROR HANDLING ---

HIBERNATE_EXIT_CODE=$?

if [ $HIBERNATE_EXIT_CODE -ne 0 ]; then
  echo "Error: Hibernation failed!"
  echo "Canceling BootNext flag to prevent boot loop..."
  # Cancel the next boot flag to prevent getting stuck booting other OS
  efibootmgr -N &>/dev/null
  exit 1
else
  echo "Welcome back!"
fi
