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
  local deps=(systemctl findmnt jq lsof)

  # Check generic dependencies
  for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: Required command '$cmd' is missing."
      exit 1
    fi
  done
}

detect_bootloader() {
  if bootctl is-installed &>/dev/null; then
    BOOTLOADER_TYPE="systemd-boot"
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

should_hide_entry() {
  local entry="$1"

  if [ "${HIDE_TECHNICAL_ENTRIES:-false}" == "true" ] && [ -n "${TECHNICAL_KEYWORDS:-}" ]; then
    [[ "$entry" =~ $TECHNICAL_KEYWORDS ]]
    return $?
  fi

  return 1
}

select_entry_systemd() {
  echo "--- systemd-boot Entries ---"

  local ids=()
  local titles=()
  local id=""
  local title=""
  local version=""
  local label=""

  while IFS=$'\t' read -r id title version; do
    [ -z "$id" ] && continue

    if [ -n "$title" ]; then
      label="$title"
      [ -n "$version" ] && label="$label ($version)"
    else
      label="$id (Absent/Broken)"
    fi

    if should_hide_entry "$label"; then
      continue
    fi

    ids+=("$id")
    titles+=("$label")
  done < <(bootctl list --json=short | jq -r '.[] | [(.id // ""), (.title // ""), (.version // "")] | @tsv')

  if [ ${#ids[@]} -eq 0 ]; then
    echo "No boot entries available after filtering."
    exit 1
  fi

  # Display Menu
  for i in "${!ids[@]}"; do
    printf "[%d] %s\n" "$((i + 1))" "${titles[$i]}"
  done

  # User Selection Logic
  read -p "Select OS number: " selection

  # Input Validation
  if ! [[ "$selection" =~ ^[1-9][0-9]*$ ]]; then
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

  local ids=()
  local titles=()
  local entry=""
  local grub_cfg="/boot/grub/grub.cfg"

  if [ ! -f "$grub_cfg" ]; then
    # Some distros use /boot/grub2
    grub_cfg="/boot/grub2/grub.cfg"
    if [ ! -f "$grub_cfg" ]; then
      echo "Error: Cannot find grub.cfg"
      exit 1
    fi
  fi

  # Build IDs for grub-reboot. Nested entries use "submenu>entry" format
  mapfile -t ids < <(jq -R -n -r '
    def indent: capture("^(?<i>[ \t]*)").i | gsub("\t"; "  ") | length;
    def title($line): ($line | capture("^[[:space:]]*(submenu|menuentry)[[:space:]]+[\"\x27](?<t>[^\"\x27]+)").t?);

    reduce inputs as $line (
      {stack: [], entries: []};
      if ($line | test("^[[:space:]]*submenu[[:space:]]+[\"\x27]")) then
        ($line | indent) as $depth
        | ($line | title(.)) as $name
        | if $name == null then . else
            .stack |= ([.[] | select(.depth < $depth)] + [{depth: $depth, name: $name}])
          end
      elif ($line | test("^[[:space:]]*menuentry[[:space:]]+[\"\x27]")) then
        ($line | indent) as $depth
        | ($line | title(.)) as $name
        | if $name == null then . else
            (.stack
              | map(select(.depth < $depth) | .name)
              | if length == 0 then "" else (join(">") + ">") end) as $path
            | .entries += [$path + $name]
          end
      else
        .
      end
    )
    | .entries[]
  ' "$grub_cfg")

  for entry in "${ids[@]}"; do
    if should_hide_entry "$entry"; then
      continue
    fi
    titles+=("$entry")
  done

  ids=("${titles[@]}")

  if [ ${#ids[@]} -eq 0 ]; then
    echo "No GRUB entries available after filtering."
    exit 1
  fi

  for i in "${!titles[@]}"; do
    printf "[%d] %s\n" "$((i + 1))" "${titles[$i]}"
  done

  read -p "Select OS number: " selection

  if ! [[ "$selection" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid input"
    exit 1
  fi
  local index=$((selection - 1))

  if [ -z "${titles[$index]}" ]; then
    echo "Out of range"
    exit 1
  fi

  TARGET_ID="${ids[$index]}"
  TARGET_TITLE="${titles[$index]}"
  echo "Selected: $TARGET_TITLE"
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
