{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.swapos;
in {
  options.programs.swapos = {
    enable = mkEnableOption "swap-os utility";
    
    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./package.nix {};
      description = "The swapos package to use.";
    };

    protectedPaths = mkOption {
      type = types.listOf types.str;
      default = [ "/nix" "/nix/store" "/boot" "/efi" "/home" ];
      description = "List of mount points to NEVER unmount.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    systemd.packages = [ cfg.package ];

    environment.etc."systemd/system-sleep/swapos-hibernate".source =
      "${cfg.package}/lib/systemd/system-sleep/hibernate.sh";

    environment.etc."swapos/config".text = ''
      PROTECTED_PATHS="^/($|dev|proc|sys|run|tmp|var|etc|root|usr|bin|sbin|lib|lib64|opt|srv|${concatStringsSep "|" (map (removePrefix "/") cfg.protectedPaths)})(/|$)"
    '';
  };
}
