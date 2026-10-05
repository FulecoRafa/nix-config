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
      pkgs.papers
      pkgs.wl-clipboard
      pkgs.xdg-user-dirs
      pkgs.xdg-utils
      tesseract
    ];
    text = builtins.readFile ./screenshot-ocr;
  };

  # Captura para o cartão "captura pronta" do shell (Capture.qml).
  shellCapture = pkgs.writeShellApplication {
    name = "shell-capture";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gradia
      pkgs.hyprshot
      pkgs.libnotify
      pkgs.quickshell
    ];
    text = builtins.readFile ./shell-capture;
  };
  capture = mode: "${lib.getExe shellCapture} ${mode}";
  # Sem o shell no ar, captura o monitor em foco direto.
  captureUi = "${lib.getExe pkgs.quickshell} -c fuleco ipc call capture open || ${capture "output"}";
  hud = id: "${lib.getExe pkgs.quickshell} -c fuleco ipc call hud flash ${id} & ";
in
{
  home.packages = [
    pkgs.gradia
    pkgs.hyprshot
    pkgs.papers
    shellCapture
    screenshotOcr
    tesseract
  ];

  # Gradia e o PDF do OCR (Papers) abrem sempre flutuando, grandes e no
  # centro, por cima do que estiver no tiling.
  wayland.windowManager.hyprland.settings.windowrule = [
    "match:class ^(be\\.alexandervanhee\\.gradia|org\\.gnome\\.Papers)$, float on, center on, size (monitor_w*0.85) (monitor_h*0.85)"
  ];

  wayland.windowManager.hyprland.settings.bind = [
    # PRINT abre a barra de modos (região/janela/tela); o resultado vai para
    # o cartão "captura pronta" (copiar, salvar, gradia, extrair texto).
    ", PRINT, exec, ${captureUi}"
    "SHIFT, PRINT, exec, ${capture "output"}"
    "SUPER, PRINT, exec, ${capture "window"}"
    "SUPER SHIFT, PRINT, exec, ${capture "region"}"

    # Atalhos do design (com o HUD), para teclados sem PRINT fácil.
    "SUPER SHIFT, S, exec, ${hud "shift-s"}${capture "region"}"
    "SUPER SHIFT, O, exec, ${hud "shift-o"}${lib.getExe screenshotOcr} region"

    # Captura seguida de edição/anotação no Gradia.
    "CTRL, PRINT, exec, ${lib.getExe pkgs.hyprshot} -m region -- ${lib.getExe pkgs.gradia}"
    "SUPER CTRL, PRINT, exec, ${lib.getExe pkgs.hyprshot} -m window -- ${lib.getExe pkgs.gradia}"

    # Captura seguida de OCR: texto no clipboard e PDF pesquisável aberto.
    "ALT, PRINT, exec, ${lib.getExe screenshotOcr} region"
    "SUPER ALT, PRINT, exec, ${lib.getExe screenshotOcr} window"
  ];
}
