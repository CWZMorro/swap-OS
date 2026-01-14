#!/bin/bash

# File to store the list of unmounted partitions
STATE_FILE="/run/swapos/unmounted_targets"

safety_check_and_unmount() {
  : "${PROTECTED_PATHS:="^/($|boot|efi|dev|proc|sys|run|tmp|var|usr|etc|root|home|nix|gnu|opt|srv|bin|lib|lib64|sbin)"}"

  # Get the Dynamic ESP path from systemd-boot
  local esp_path
  esp_path=$(bootctl -p 2>/dev/null)

  # findmnt: List all mounts
  # -r: Raw output
  # -n: No headings
  # --source-mode: Show device source
  # --types "not ...": Exclude virtual filesystems like tmpfs, proc, etc.
  # grep -vE: Exclude our Protected List
  local targets
  targets=$(findmnt -rn --source-mode --output TARGET --types "not tmpfs,devtmpfs,proc,sysfs,efivarfs,cgroup,cgroup2,autofs,binfmt_misc,configfs,debugfs,devpts,fusectl,hugetlbfs,mqueue,pstore,securityfs,tracefs" | grep -vE "$PROTECTED_PATHS" | sort -r)

  if [ -z "$targets" ]; then
    echo "No risky partitions detected."
    return 0
  fi

  echo "Detected shared partitions that must be unmounted:"

  local safe_targets=""
  while read -r mountpoint; do
    if [[ -n "$esp_path" ]] && [[ "$mountpoint" == "$esp_path" ]]; then
      echo "Skipping ESP (Boot Partition): $mountpoint"
      continue
    fi

    if [[ "$mountpoint" == "/boot" ]] || [[ "$mountpoint" == "/efi" ]]; then
      echo "Skipping Protected Path: $mountpoint"
      continue
    fi

    echo "$mountpoint"
    safe_targets+="$mountpoint"$'\n'
  done <<<"$targets"

  if [ -z "$safe_targets" ]; then
    echo "All targets were protected. Nothing to unmount."
    return 0
  fi

  # Create the state directory in /run
  mkdir -p "$(dirname "$STATE_FILE")"
  : >"$STATE_FILE"

  # Unmount Loop
  local failure_count=0

  while read -r mountpoint; do
    if [ -z "$mountpoint" ]; then continue; fi

    echo -n "Unmounting $mountpoint... "

    # Check if busy using lsof
    if command -v lsof &>/dev/null; then
      if lsof +D "$mountpoint" &>/dev/null; then
        echo "BUSY (Skipping - Close files first!)"
        ((failure_count++))
        continue
      fi
    fi

    # Attempt unmount
    if umount "$mountpoint"; then
      echo "OK"
      echo "$mountpoint" >>"$STATE_FILE"
    else
      echo "FAILED"
      ((failure_count++))
    fi
  done <<<"$safe_targets"

  if [ "$failure_count" -gt 0 ]; then
    echo "Error: Failed to unmount $failure_count partition(s)."
    echo "Aborting hibernation to prevent data corruption."
    restore_mounts
    exit 1
  fi
}

restore_mounts() {
  if [ ! -f "$STATE_FILE" ]; then
    return 0
  fi

  echo "Restoring partitions..."

  while read -r mountpoint; do
    echo -n "Remounting $mountpoint... "
    if mount "$mountpoint"; then
      echo "OK"
    else
      echo "FAILED (Ensure this drive is in /etc/fstab)"
    fi
  done <"$STATE_FILE"

  # Clean up
  rm -f "$STATE_FILE"
}
