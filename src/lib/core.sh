#!/bin/bash

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Error: This application requires root privileges."
    exit 1
  fi
}

check_dependencies() {
  # systemd-boot requires 'bootctl'
  # We still check efibootmgr as a backup/utility
  for cmd in bootctl efibootmgr systemctl findmnt grep; do
    if ! command -v $cmd &>/dev/null; then
      echo "Error: Required command '$cmd' is not installed."
      exit 1
    fi
  done

  if ! bootctl is-installed &>/dev/null; then
    echo "Error: systemd-boot is not detecting your bootloader."
    echo "This version of swap-os requires systemd-boot to function safely."
    exit 1
  fi
}

select_boot_entry() {
  echo "--- Available Boot Entries (systemd-boot) ---"

  # We parse 'bootctl list' to get clean titles and IDs
  # Format: Title (ID)
  local entries
  entries=$(bootctl list --no-pager)

  # Arrays to hold data
  local titles=()
  local ids=()

  # Temporary loop to parse the list safely
  # looking for lines starting with "title:" and "id:"
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*title:[[:space:]]*(.*)$ ]]; then
      titles+=("${BASH_REMATCH[1]}")
    elif [[ "$line" =~ ^[[:space:]]*id:[[:space:]]*(.*)$ ]]; then
      ids+=("${BASH_REMATCH[1]}")
    fi
  done <<<"$entries"

  # Display Menu
  for i in "${!ids[@]}"; do
    printf "[%d] %s\n" "$((i + 1))" "${titles[$i]}"
  done
  echo "------------------------------"

  read -p "Select OS number: " selection

  if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid input."
    exit 1
  fi

  local index=$((selection - 1))

  if [ -z "${ids[$index]}" ]; then
    echo "Error: Selection out of range."
    exit 1
  fi

  TARGET_ID="${ids[$index]}"
  TARGET_TITLE="${titles[$index]}"

  echo "Target Selected: $TARGET_TITLE ($TARGET_ID)"
}

perform_hibernation() {
  # The Magic: "oneshot" tells systemd-boot to pick this ID only once
  echo "Setting systemd-boot one-shot flag..."

  if ! bootctl set-oneshot "$TARGET_ID"; then
    echo "Error: Failed to set boot flag."
    exit 1
  fi

  echo "System is going down for hibernation..."
  sleep 2

  if ! systemctl hibernate; then
    echo "CRITICAL ERROR: Hibernation command failed."
    echo "Clearing boot flag to prevent boot loop..."
    bootctl set-oneshot ""

    # Attempt to remount if safety.sh was used
    if type restore_mounts &>/dev/null; then restore_mounts; fi
    exit 1
  fi

  # If we wake up here, we are back in Linux.
  echo "System has resumed from hibernation."

  if [ "${AUTO_REMOUNT:-true}" == "true" ]; then
    if type restore_mounts &>/dev/null; then restore_mounts; fi
  fi
}
