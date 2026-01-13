{
  description = "A tool to enable seemless swap between different OS";

  # Dependencies
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    # Helper to support multiple architectures (x86, arm, etc.)
    forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
  in {
    
    # The Package Definition
    packages = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.callPackage ./package.nix {};
    });

    # The NixOS Module (for configuration.nix)
    nixosModules.default = import ./module.nix;
    
    # Dev Shell
    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        # Tools in the dev shell
        buildInputs = with pkgs; [ bash efibootmgr util-linux gnumake ];
      };
    });
  };
}
