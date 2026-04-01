#!/bin/bash

STATE_FILE="/run/swapos/unmounted_targets"

safety_check_and_unmount() {
  # Default list of protected paths (regex)
  : "${PROTECTED_PATHS:="^/($|boot|efi|dev|proc|sys|run|tmp|var|usr|etc|root|home|nix|nix/store|gnu|opt|srv|bin|lib|lib64|sbin)(/|$)"}"

  local targets_json
  targets_json=$(findmnt -J -l | jq -c --arg regex "$PROTECTED_PATHS" '
    [
      .filesystems[]?
      | select((.fstype // "") | test("^(tmpfs|devtmpfs|proc|sysfs|efivarfs|cgroup|cgroup2|autofs|fusectl|debugfs|tracefs)$") | not)
      | select((.target // "") | test($regex) | not)
      | { source: (.source // ""), target: (.target // ""), options: (.options // "") }
    ]
  ')

  if jq -e 'length == 0' >/dev/null 2>&1 <<<"$targets_json"; then
    echo "No risky partitions detected."
    return 0
  fi

  echo "Detected partitions to secure:"
  jq -r '.[].target' <<<"$targets_json"

  mkdir -p "$(dirname "$STATE_FILE")"
  : >"$STATE_FILE"

  while IFS=$'\t' read -r device mountpoint options; do
    if [ -z "$mountpoint" ]; then continue; fi

    # If user/system intentionally keeps it read-only, do not touch it.
    if [[ "$options" =~ (^|,)ro(,|$) ]]; then
      echo "Skipping $mountpoint (Already Read-Only)"
      continue
    fi

    # Try to Remount Read-Only (Safest, fastest)
    echo -n "Attempting to lock $mountpoint (Read-Only)... "

    if mount -o remount,ro "$mountpoint" 2>/dev/null; then
      echo "OK (Read-Only)"
      # Mark as "RO" in state file
      printf 'RO\t%s\t%s\n' "$device" "$mountpoint" >>"$STATE_FILE"
      continue
    fi

    # If RO fails, try full unmount
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
      printf 'UM\t%s\t%s\n' "$device" "$mountpoint" >>"$STATE_FILE"
    else
      echo "FAILED. Cannot secure $mountpoint."
      exit 1
    fi

  done < <(jq -r '.[] | [(.source // ""), (.target // ""), (.options // "")] | @tsv' <<<"$targets_json")
}

restore_mounts() {
  if [ ! -f "$STATE_FILE" ]; then return 0; fi

  echo "Restoring partitions..."

  while IFS=$'\t' read -r type device mountpoint; do
    if [ -z "$mountpoint" ] && [ -n "$type" ]; then
      # Backward-compatible parser for older state format: TYPE:/mountpoint
      mountpoint="${type#*:}"
      type="${type%%:*}"
      device=""
    fi

    if [ "$type" == "RO" ]; then
      echo -n "Restoring Read-Write on $mountpoint... "
      if mount -o remount,rw "$mountpoint"; then echo "OK"; else echo "FAILED"; fi

    elif [ "$type" == "UM" ]; then
      echo -n "Remounting $mountpoint... "
      if [ -n "$device" ] && mount "$device" "$mountpoint"; then
        echo "OK"
      elif mount "$mountpoint"; then
        echo "OK"
      else
        echo "FAILED"
      fi
    fi

  done <"$STATE_FILE"

  rm -f "$STATE_FILE"
}
