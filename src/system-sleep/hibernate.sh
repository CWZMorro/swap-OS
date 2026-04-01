#!/bin/bash

LOCK_FILE_BOOT="/run/swapos/boot_was_rw"
LOCK_FILE_BOOT_EFI="/run/swapos/boot_efi_was_rw"
LOCK_FILE_EFI="/run/swapos/efi_was_rw"

case "$1/$2" in
pre/*hibernate*|pre/*sleep*)
  mkdir -p /run/swapos
  sync

  # Handle /boot
  if findmnt -J /boot 2>/dev/null | jq -e '.filesystems[0].options | test("(^|,)rw(,|$)")' >/dev/null; then
    touch "$LOCK_FILE_BOOT"
    if ! mount -o remount,ro /boot; then
      echo "CRITICAL: SWAPOS failed to lock /boot. System data at risk!"
      rm -f "$LOCK_FILE_BOOT"
      exit 1
    fi
  fi

  # Handle /boot/efi (common EFI mountpoint on many distros)
  if findmnt -J /boot/efi 2>/dev/null | jq -e '.filesystems[0].options | test("(^|,)rw(,|$)")' >/dev/null; then
    touch "$LOCK_FILE_BOOT_EFI"
    if ! mount -o remount,ro /boot/efi; then
      echo "CRITICAL: SWAPOS failed to lock /boot/efi. System data at risk!"
      rm -f "$LOCK_FILE_BOOT_EFI"
      exit 1
    fi
  fi

  # Handle /efi
  if findmnt -J /efi 2>/dev/null | jq -e '.filesystems[0].options | test("(^|,)rw(,|$)")' >/dev/null; then
    touch "$LOCK_FILE_EFI"
    if ! mount -o remount,ro /efi; then
      echo "CRITICAL: SWAPOS failed to lock /efi. System data at risk!"
      rm -f "$LOCK_FILE_EFI"
      exit 1
    fi
  fi
  ;;
post/*hibernate*|post/*sleep*)
  if [ -f "$LOCK_FILE_BOOT" ]; then
    mount -o remount,rw /boot
    rm -f "$LOCK_FILE_BOOT"
  fi
  if [ -f "$LOCK_FILE_BOOT_EFI" ]; then
    mount -o remount,rw /boot/efi
    rm -f "$LOCK_FILE_BOOT_EFI"
  fi
  if [ -f "$LOCK_FILE_EFI" ]; then
    mount -o remount,rw /efi
    rm -f "$LOCK_FILE_EFI"
  fi
  ;;
esac
