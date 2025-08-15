
{ pkgs, inputs, ... }:

{
  programs.helix.languages = {
    language = [
      {
        name = "dockerfile";
        file-types = [
          "dockerfile"
          "containerfile"
          { glob = "Dockerfile"; }
          { glob = "Dockerfile*"; }
          { glob = "dockerfile"; }
          { glob = "dockerfile*"; }
          { glob = "Containerfile"; }
          { glob = "Containerfile*"; }
          { glob = "containerfile"; }
          { glob = "containerfile*"; }
        ];
      }
    ];

    language-server.scls = {
      command = "simple-completion-language-server";
      config = {
        max_completion_items         = 100;   # Max suggestions for each group: words, snippets, unicode-input
        feature_words                = true;  # enable completion by word
        feature_snippets             = true;  # enable snippets
        snippets_first               = true;
        snippets_inline_by_word_tail = false; # 'xsq' -> 'x^2' if true and `sq = ^2`
        feature_unicode_input        = false; # enable emoji and other shit
        feature_paths                = false; # already on helix, no need
        feature_citations            = false; # do I look like a scientist??
      };
      environment = {
        RUST_LOG = "info,simple-completion-language-server=info";
        LOG_FILE = "/tmp/completion.log";
      };
    };
  };
}
