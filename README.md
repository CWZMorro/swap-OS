# Swap-OS

A tool that enables swap between differnt OS.  Multiple OS are supported.
Read the wiki for more info.

If you don't trust this tool, you can manually configure it following the wiki guide.

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

- UEFI System

- swapfile configured

- bootloader Configured (You must have resume=UUID=... in your kernel parameters.)

- sudo privilages

More details can be found in the wiki

## Uninstall (for manual install users only)
```
## cd to the swap-OS directory
./uninstall.sh
```
