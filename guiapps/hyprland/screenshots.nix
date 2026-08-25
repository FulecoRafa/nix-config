{ lib, pkgs, ... }:

let
  tesseract = pkgs.tesseract.override {
    enableLanguages = [
      "eng"
      "por"
    ];
  };

  screenshotOcr = pkgs.writeShellApplication {
    name = "screenshot-ocr";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.hyprshot
      pkgs.libnotify
      pkgs.xdg-user-dirs
      pkgs.xdg-utils
      tesseract
    ];
    text = builtins.readFile ./screenshot-ocr;
  };
in
{
  home.packages = [
    pkgs.gradia
    pkgs.hyprshot
    screenshotOcr
    tesseract
  ];

  wayland.windowManager.hyprland.settings.bind = [
    # Capturas rápidas: salvam a imagem e a copiam para o clipboard.
    ", PRINT, exec, ${lib.getExe pkgs.hyprshot} -m output"
    "SUPER, PRINT, exec, ${lib.getExe pkgs.hyprshot} -m window"
    "SUPER SHIFT, PRINT, exec, ${lib.getExe pkgs.hyprshot} -m region"

    # Captura seguida de edição/anotação no Gradia.
    "CTRL, PRINT, exec, ${lib.getExe pkgs.hyprshot} -m region -- ${lib.getExe pkgs.gradia}"
    "SUPER CTRL, PRINT, exec, ${lib.getExe pkgs.hyprshot} -m window -- ${lib.getExe pkgs.gradia}"

    # Captura seguida de OCR português/inglês em um PDF pesquisável.
    "ALT, PRINT, exec, ${lib.getExe screenshotOcr} region"
    "SUPER ALT, PRINT, exec, ${lib.getExe screenshotOcr} window"
  ];
}
