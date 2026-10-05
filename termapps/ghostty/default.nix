{ ... }:

{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "CaskaydiaCove Nerd Font";
      font-size = 14;
      shell-integration = "zsh";
      background = "#1f2430";
      # Leve transparência; o blur fica a cargo do compositor (Hyprland) ou
      # do próprio Ghostty no macOS.
      background-opacity = 0.88;
      background-blur = true;
      foreground = "#cbccc6";
      cursor-color = "#ffcc66";
      cursor-text = "#1f2430";
      selection-background = "#33415e";
      selection-foreground = "#cbccc6";
      palette = [
        "0=#191e2a"
        "1=#f28779"
        "2=#bae67e"
        "3=#ffd580"
        "4=#73d0ff"
        "5=#d4bfff"
        "6=#95e6cb"
        "7=#c7c7c7"
        "8=#686868"
        "9=#f07178"
        "10=#c2d94c"
        "11=#ffcc66"
        "12=#59c2ff"
        "13=#d2a6ff"
        "14=#95e6cb"
        "15=#ffffff"
      ];

      # Cursor trail (Neovide-inspired) from sahaj-b/ghostty-cursor-shaders.
      # The shader is vendored alongside this module and referenced by its
      # nix store path so it is available wherever this config is deployed.
      custom-shader = "${./cursor_warp.glsl}";
      # Keep the shader animating even when the window is unfocused, otherwise
      # the line cursor freezes mid-trail on unfocus.
      custom-shader-animation = "always";
    };
  };
}
