{ pkgs, ... }:
let
  aiUsage = pkgs.writeShellApplication {
    name = "ai-usage";
    runtimeInputs = [
      pkgs.codex
      pkgs.python3
    ];
    text = ''
      exec python3 ${./ai-usage.py} "$@"
    '';
  };
in
{
  programs = {
    claude-code = {
      enable = true;
      settings.statusLine = {
        type = "command";
        command = "${aiUsage}/bin/ai-usage claude-statusline";
        padding = 0;
      };
    };

    codex.enable = true;
  };

  home.packages = [ aiUsage ];
}
