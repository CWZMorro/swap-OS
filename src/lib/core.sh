#!/bin/bash

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Error: This application requires root privileges."
    exit 1
  fi
}

check_dependencies() {
  # Loop through list of required commands
  for cmd in efibootmgr systemctl findmnt grep; do
    if ! command -v $cmd &>/dev/null; then
      echo "Error: Required command '$cmd' is not installed."
      exit 1
    fi
  done
}

select_boot_entry() {
  # Get raw output from efibootmgr
  local raw_output
  raw_output=$(efibootmgr)

  local ids=()
  local names=()
  local i=0

  echo "--- Available Boot Entries ---"

  while read -r line; do
    if [[ $line =~ ^Boot([0-9A-F]{4})(\*?)\ (.*)$ ]]; then
      local id="${BASH_REMATCH[1]}"
      local name="${BASH_REMATCH[3]}"

      if [ "$HIDE_TECHNICAL_ENTRIES" == "true" ]; then
        : "${TECHNICAL_KEYWORDS:="HD|PciRoot|Pci|Acpi|VenHw|VenMsg|Usb|USB|File|Uri|MAC|NVMe|Sata|CD|Fv"}"

        name=$(echo "$name" | sed -E "s/[[:space:]]+($TECHNICAL_KEYWORDS)\(.*$//")
      fi

      ids+=("$id")
      names+=("$name")

      printf "[%d] %s (ID: %s)\n" "$((i + 1))" "$name" "$id"
      ((i++))
    fi
  done <<<"$raw_output"

  echo "------------------------------"

  # Read user input
  read -p "Select OS number (1-$i): " selection

  if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid input."
    exit 1
  fi

  local index=$((selection - 1))

  if [ "$index" -ge 0 ] && [ "$index" -lt "$i" ]; then
    TARGET_ID="${ids[$index]}"
    echo "Target Selected: ${names[$index]} ($TARGET_ID)"
  else
    echo "Error: Selection out of range."
    exit 1
  fi
}

perform_hibernation() {
  # Set BootNext variable in EFI vars
  echo "Setting EFI BootNext to $TARGET_ID..."
  if ! efibootmgr --bootnext "$TARGET_ID" &>/dev/null; then
    echo "Error: Failed to set BootNext flag."
    # Remount previously unmounted drives if fail
    if type restore_mounts &>/dev/null; then restore_mounts; fi
    exit 1
  fi

  echo "System is going down for hibernation..."
  sleep 2

  if ! systemctl hibernate; then
    echo "CRITICAL ERROR: Hibernation command failed."
    efibootmgr -N &>/dev/null
    if type restore_mounts &>/dev/null; then restore_mounts; fi
    exit 1
  fi

  echo "System has resumed from hibernation."

  if [ "$AUTO_REMOUNT" == "true" ]; then
    restore_mounts
  fi
}
