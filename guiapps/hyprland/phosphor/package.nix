{ fetchurl, stdenvNoCC }:

# Ícones Phosphor (variante fill) como fonte, usados pelo Quickshell.
# O mapa nome → codepoint fica em quickshell/Icons.qml.
stdenvNoCC.mkDerivation {
  pname = "phosphor-icons-fill";
  version = "2.1.1";

  src = fetchurl {
    url = "https://unpkg.com/@phosphor-icons/web@2.1.1/src/fill/Phosphor-Fill.ttf";
    hash = "sha256-pT9dJjDKteO3U27LnWnXFRmiGQKYwisfjXcN03vClAo=";
  };

  dontUnpack = true;

  installPhase = ''
    install -Dm444 $src $out/share/fonts/truetype/Phosphor-Fill.ttf
  '';
}
