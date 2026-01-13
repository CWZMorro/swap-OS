# Swap-OS

A tool that enables swap between differnt OS.  Multiple OS are supported.
Read the wiki for more info.

If you don't trust this tool, you can manually configure it following the wiki guide.

## Requirements

- **UEFI System** (Legacy BIOS is not supported)
- **Swap file or swap partition configured**
- **Bootloader configured** (Kernel parameters must include `resume=UUID=...` or systemd-hibernate configured)
- sudo privilages

## Installation

### Arch Linux (AUR (yay/paru)):
```
yay swap-os-git
```

### NixOS (Flake):
Run temporarily
```
nix run github:CWZMorro/swap-os --impure
```
Install permanently (Flake) 
```
# Add to your configuration.nix or flake.nix
# flake.nix
{
  inputs.swapos.url = "github:CWZMorro/swap-os";
  
  outputs = { self, nixpkgs, swapos, ... }: {
    nixosConfigurations.myMachine = nixpkgs.lib.nixosSystem {
      modules = [
        swapos.nixosModules.default
        {
          programs.swapos = {
            enable = true;
            # Optional: Add extra paths to protect from unmounting
            protectedPaths = [ "/home/games" "/mnt/archive" ]; 
          };
        }
      ];
    };
  };
}
```
### Other Distros (Manual Install)
Dependencies: bash, efibootmgr, util-linux, systemd, make
```
git clone https://github.com/CWZMorro/swap-OS
cd swap-OS
sudo make install
```
## Usage
```
sudo swapos
```
## CRITICAL Windows Configuration

  1. Boot into Windows. (Tips: you can just use swapos and make sure it works)

  2. Open Control Panel -> Hardware and Sound -> Power Options

  3. Click "Choose what the power buttons do"

  4. Click "Change settings that are currently unavailable" (Shield Icon)

  5. UNCHECK "Turn on fast startup"

  6. CHECK "Hibernate" (Enables hibernate option in start)

  7. Save changes
