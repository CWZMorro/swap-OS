{ lib, stdenv, makeWrapper, efibootmgr, util-linux, systemd, bash }:

stdenv.mkDerivation {
  pname = "swapos";
  version = "2.0.0";

  src = ../.;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ bash ];

  installPhase = ''
    mkdir -p $out/bin $out/lib/swapos $out/share/doc/swapos

    cp src/swapos $out/bin/swapos
    cp src/lib/core.sh $out/lib/swapos/core.sh
    cp src/lib/safety.sh $out/lib/swapos/safety.sh

    chmod +x $out/bin/swapos

    wrapProgram $out/bin/swapos \
      --prefix PATH : ${lib.makeBinPath [ efibootmgr util-linux systemd ]} \
      --set SWAPOS_LIB $out/lib/swapos
  '';

  meta = with lib; {
    description = "A tool to enable seemless swap between different OS";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [
      {
          name = "CWZ_Morro";
          email = "cwzmorro@gmail.com";
          github = "CWZMorro";
        }
    ];
  };
}
