# Swap-OS (swindows)

A tool to hibernate Linux and reboot directly into Windows. This tool is based on https://github.com/CWZMorro/linux-windows-switch

## Installation
```
git clone https://github.com/CWZMorro/swap-OS.git
cd swap-OS
./install.sh
```

## Usage
```
sudo swindows
```

## Requirements

1. UEFI System

2. Swapfile configured 

3. Bootloader Configured: You must have resume=UUID=... in your kernel parameters.

### Note:
  (Refer to https://github.com/CWZMorro/linux-windows-switch step 1, 2 & 3 if you're missing any of the requirement)
