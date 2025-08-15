{...}:

{
    programs.helix.settings = {
    theme = "catppuccin_mocha";
    editor = {
      line-number = "relative";
      rulers = [ 80 120 ];
      bufferline = "multiple";
      statusline = {
        left = ["version-control" "spinner" "file-name" "file-type" "read-only-indicator" "file-modification-indicator"];
        center = ["mode"];
      };
      cursor-shape = {
        insert = "bar";
      };
      lsp = {
        display-inlay-hints = true;
      };
      whitespace = {
        render = "all";
        characters = {
          tabpad  = " ";
          space   = "·";
          nbsp    = "⍽";
          nnbsp   = "␣";
          tab     = "→";
          newline = "↩";
        };
      };
      indent-guides = {
        render = true;
      };
      file-picker = {
        hidden = false;
      };
    };
    keys = {
      normal = {
        space = {
          H = ":toggle lsp.display-inline-hints";
          z = ":toggle soft-wrap.enable";
          B = ":sh jj file annotate %{buffer_name} | awk '$5==\"%{cursor_line}:\"'";
          A = {
            j = ":insert-output jq -S . %{buffer_name}";
          };
        };
      };
    };
  };
}
