# Swap-OS

A tool to hibernate Linux and reboot directly into Windows.
Read the wiki for more info.

## Installation
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

## Uninstall
```
## cd to the swap-OS directory
./uninstall.sh
```
