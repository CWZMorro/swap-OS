# Swap-OS

A tool that enables swap between differnt OS.  Multiple OS are supported.
Read the wiki for more info.

## Installation

### Using AUR (yay/paru):
```
yay swap-os-git
```
### Manual install:
```
git clone https://github.com/CWZMorro/swap-OS.git
cd swap-OS
./install.sh
```

## Usage
```
sudo swapos
```

## Requirements

UEFI System

Swapfile configured

Bootloader Configured: You must have resume=UUID=... in your kernel parameters.

## Uninstall (for manual install users only)
```
## cd to the swap-OS directory
./uninstall.sh
```
