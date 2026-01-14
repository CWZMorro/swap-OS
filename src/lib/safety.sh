#!/bin/bash

STATE_FILE="/run/swapos/unmounted_targets"

safety_check_and_unmount() {
  # Default list of protected paths (regex)
  : "${PROTECTED_PATHS:="^/($|boot|efi|dev|proc|sys|run|tmp|var|usr|etc|root|home|nix|gnu|opt|srv|bin|lib|lib64|sbin)"}"

  # Get list of targets
  local targets
  targets=$(findmnt -rn --source-mode --output TARGET --types "not tmpfs,devtmpfs,proc,sysfs,efivarfs,cgroup,cgroup2,autofs,fusectl,debugfs,tracefs" | grep -vE "$PROTECTED_PATHS" | sort -r)

  if [ -z "$targets" ]; then
    echo "No risky partitions detected."
    return 0
  fi

  echo "Detected partitions to secure:"
  echo "$targets"

  mkdir -p "$(dirname "$STATE_FILE")"
  : >"$STATE_FILE"

  while read -r mountpoint; do
    if [ -z "$mountpoint" ]; then continue; fi

    # Try to Remount Read-Only (Safest, fastest)
    echo -n "Attempting to lock $mountpoint (Read-Only)... "

    if mount -o remount,ro "$mountpoint" 2>/dev/null; then
      echo "OK (Read-Only)"
      # Mark as "RO" in state file
      echo "RO:$mountpoint" >>"$STATE_FILE"
      continue
    fi

    # If RO fails (files are open), try full unmount
    echo "Busy. Attempting full unmount..."

    # Check for open files
    if command -v lsof &>/dev/null; then
      if lsof +D "$mountpoint" &>/dev/null; then
        echo "  WARNING: Files are open on $mountpoint. Hibernation might corrupt data if you proceed."
        echo "  ABORTING: Close files on $mountpoint first."
        exit 1
      fi
    fi

    if umount "$mountpoint"; then
      echo "OK (Unmounted)"
      echo "UM:$mountpoint" >>"$STATE_FILE"
    else
      echo "FAILED. Cannot secure $mountpoint."
      exit 1
    fi

  done <<<"$targets"
}

restore_mounts() {
  if [ ! -f "$STATE_FILE" ]; then return 0; fi

  echo "Restoring partitions..."

  while read -r line; do
    local type="${line%%:*}"
    local mountpoint="${line#*:}"

    if [ "$type" == "RO" ]; then
      echo -n "Restoring Read-Write on $mountpoint... "
      if mount -o remount,rw "$mountpoint"; then echo "OK"; else echo "FAILED"; fi

    elif [ "$type" == "UM" ]; then
      echo -n "Remounting $mountpoint... "
      if mount "$mountpoint"; then echo "OK"; else echo "FAILED"; fi
    fi

  done <"$STATE_FILE"

  rm -f "$STATE_FILE"
}
