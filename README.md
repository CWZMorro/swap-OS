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


## CRITICAL Windows Configuration

  1. Boot into Windows. (Tips: you can just use swapos and make sure it works)

  2. Open Control Panel -> Hardware and Sound -> Power Options

  3. Click "Choose what the power buttons do"

  4. Click "Change settings that are currently unavailable" (Shield Icon)

  5. UNCHECK "Turn on fast startup"

  6. CHECK "Hibernate" (Enables hibernate option in start)

  7. Save changes
