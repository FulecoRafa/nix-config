{ lib, pkgs }:

let
  version = "0.15.4.1";
  sources = {
    x86_64-linux = {
      arch = "x86_64";
      hash = "sha256-h3yxZnMb/EHvPJALQlJgHUVYUNsfuv0pnewgf6K6sx8=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-VNVETBXVO1skExhK3maw7N/HuFufeHRky/z1CRwjqkw=";
    };
  };
  platform = pkgs.stdenv.hostPlatform.system;
  source = sources.${platform} or (throw "Helium não está empacotado para ${platform}");
  appimage = pkgs.fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-${source.arch}.AppImage";
    inherit (source) hash;
  };
  extracted = pkgs.appimageTools.extractType2 {
    pname = "helium";
    inherit version appimage;
    src = appimage;
  };
in
pkgs.appimageTools.wrapType2 {
  pname = "helium";
  inherit version;
  src = appimage;
  # O AppRun grava $APPIMAGE (ou o próprio caminho no store) no Exec dos
  # PWAs instalados; o nome do comando sobrevive a atualizações e ao GC.
  profile = ''
    export APPIMAGE=helium
  '';
  extraInstallCommands = ''
    install -Dm644 ${extracted}/helium.desktop $out/share/applications/helium.desktop
    substituteInPlace $out/share/applications/helium.desktop \
      --replace-fail 'Exec=helium' 'Exec=helium --ozone-platform-hint=auto'
    cp -r ${extracted}/usr/share/icons $out/share/
  '';
  meta = {
    description = "Private, fast, and honest Chromium-based web browser";
    homepage = "https://helium.computer";
    license = with lib.licenses; [ gpl3Only bsd3 ];
    mainProgram = "helium";
    platforms = builtins.attrNames sources;
  };
}
