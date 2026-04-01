{ lib, stdenv, makeWrapper, util-linux, systemd, bash, jq, lsof, coreutils, grub2 }:

stdenv.mkDerivation {
  pname = "swapos";
  version = "2.2.0";

  src = ../.;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ bash jq lsof util-linux systemd coreutils grub2 ];

  installPhase = ''
    mkdir -p $out/bin $out/lib/swapos $out/share/doc/swapos $out/lib/systemd/system-sleep

    cp src/swapos $out/bin/swapos
    cp src/lib/core.sh $out/lib/swapos/core.sh
    cp src/lib/safety.sh $out/lib/swapos/safety.sh
    cp src/system-sleep/hibernate.sh $out/lib/systemd/system-sleep/hibernate.sh

    chmod +x $out/bin/swapos
    chmod +x $out/lib/systemd/system-sleep/hibernate.sh

    wrapProgram $out/bin/swapos \
      --prefix PATH : ${lib.makeBinPath [ util-linux systemd jq lsof coreutils grub2 ]} \
      --set SWAPOS_LIB $out/lib/swapos

    wrapProgram $out/lib/systemd/system-sleep/hibernate.sh \
      --prefix PATH : ${lib.makeBinPath [ util-linux jq coreutils ]}
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
