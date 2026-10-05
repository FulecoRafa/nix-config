{ lib, pkgs, ... }:

# Zsh como shell interativo: aceita a sintaxe bash/POSIX (globs, brace
# expansion, process substitution, `export`) e mantém o que usávamos no
# Nushell — histórico fuzzy (Atuin), menu de completion (fzf-tab), sugestões
# pelo histórico do diretório e edição da linha no Helix.
#
# A lógica fica em arquivos .zsh comuns para que um macOS sem nix-darwin
# possa carregá-los diretamente a partir do repositório.
{
  home.packages = with pkgs; [
    atuin
    fzf
    jq
    zsh-completions
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    defaultKeymap = "viins";
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    plugins = [
      {
        name = "fzf-tab";
        src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
      }
    ];
    envExtra = builtins.readFile ./env.zsh;
    # Depois de autosuggestions (700) e plugins como o fzf-tab (900);
    # antes do syntax-highlighting (1200).
    initContent = lib.mkOrder 1050 (builtins.readFile ./init.zsh);
  };

  xdg.configFile."atuin/config.toml".source = ./atuin.toml;
}
