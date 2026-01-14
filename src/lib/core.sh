#!/bin/bash

# Global variable to store detected loader
BOOTLOADER_TYPE=""

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Error: This application requires root privileges."
    exit 1
  fi
}

check_dependencies() {
  # Check for jq or awk
  local deps=(systemctl findmnt grep)

  # Check generic dependencies
  for cmd in "${deps[@]}"; do
    if ! command -v $cmd &>/dev/null; then
      echo "Error: Required command '$cmd' is missing."
      exit 1
    fi
  done
}

detect_bootloader() {
  if bootctl is-installed &>/dev/null; then
    BOOTLOADER_TYPE="systemd-boot"
    if ! command -v jq &>/dev/null; then
      echo "Warning: 'jq' is not installed. JSON parsing disabled (less robust)."
    fi
  elif [ -d "/boot/grub" ] && command -v grub-reboot &>/dev/null; then
    BOOTLOADER_TYPE="grub"
  else
    echo "Error: No supported bootloader detected (systemd-boot or GRUB)."
    exit 1
  fi

  echo "Detected Bootloader: $BOOTLOADER_TYPE"
}

select_boot_entry() {
  if [ "$BOOTLOADER_TYPE" == "systemd-boot" ]; then
    select_entry_systemd
  else
    select_entry_grub
  fi
}

select_entry_systemd() {
  echo "--- systemd-boot Entries ---"

  local ids=()
  local titles=()

  if command -v jq &>/dev/null; then
    # Read JSON output into arrays
    # mapfile reads lines into an array safely
    mapfile -t ids < <(bootctl list --json=short | jq -r '.[] | .id')
    mapfile -t titles < <(bootctl list --json=short | jq -r '.[] | .title')
  else
    # Fallback to using old regex method
    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]*title:[[:space:]]*(.*)$ ]]; then
        titles+=("${BASH_REMATCH[1]}")
      elif [[ "$line" =~ ^[[:space:]]*id:[[:space:]]*(.*)$ ]]; then
        ids+=("${BASH_REMATCH[1]}")
      fi
    done < <(bootctl list --no-pager)
  fi

  # Display Menu
  for i in "${!ids[@]}"; do
    printf "[%d] %s\n" "$((i + 1))" "${titles[$i]}"
  done

  # User Selection Logic
  read -p "Select OS number: " selection

  # Input Validation
  if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
    echo "Invalid input"
    exit 1
  fi
  local index=$((selection - 1))

  if [ -z "${ids[$index]}" ]; then
    echo "Out of range"
    exit 1
  fi

  TARGET_ID="${ids[$index]}"
  TARGET_TITLE="${titles[$index]}"
  echo "Selected: $TARGET_TITLE"
}

select_entry_grub() {
  echo "--- GRUB Entries ---"

  local titles=()
  local grub_cfg="/boot/grub/grub.cfg"

  if [ ! -f "$grub_cfg" ]; then
    # Some distros use /boot/grub2
    grub_cfg="/boot/grub2/grub.cfg"
    if [ ! -f "$grub_cfg" ]; then
      echo "Error: Cannot find grub.cfg"
      exit 1
    fi
  fi

  mapfile -t titles < <(awk -F\' '/^menuentry / {print $2}' "$grub_cfg")

  for i in "${!titles[@]}"; do
    printf "[%d] %s\n" "$((i + 1))" "${titles[$i]}"
  done

  read -p "Select OS number: " selection

  if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
    echo "Invalid input"
    exit 1
  fi
  local index=$((selection - 1))

  if [ -z "${titles[$index]}" ]; then
    echo "Out of range"
    exit 1
  fi

  TARGET_ID="${titles[$index]}"
}

perform_hibernation() {
  echo "Preparing to hibernate..."

  # Set the boot flag
  if [ "$BOOTLOADER_TYPE" == "systemd-boot" ]; then
    bootctl set-oneshot "$TARGET_ID"
  else
    # GRUB command
    grub-reboot "$TARGET_ID"
  fi

  # Check if command succeeded
  if [ $? -ne 0 ]; then
    echo "Error: Failed to set next boot entry."
    exit 1
  fi

  echo "Hibernating now..."
  sleep 2

  # Hibernate
  if ! systemctl hibernate; then
    echo "CRITICAL: Hibernation failed."

    # Cleanup if failed
    if [ "$BOOTLOADER_TYPE" == "systemd-boot" ]; then
      bootctl set-oneshot ""
    else
      # Reset GRUB env
      grub-editenv - unset next_entry
    fi

    # Remount drives
    if type restore_mounts &>/dev/null; then restore_mounts; fi
    exit 1
  fi

  # 3. Resume
  echo "System resumed."
  if [ "${AUTO_REMOUNT:-true}" == "true" ]; then
    if type restore_mounts &>/dev/null; then restore_mounts; fi
  fi
}
