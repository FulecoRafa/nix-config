{ pkgs, lib, ... }:

{
  home.packages = lib.attrValues {
    inherit (pkgs)
    fzf
    bat
    fd
    ;
  };

  programs.fish = {
    plugins = [{
      name = "fzf";
      src = pkgs.fetchFromGitHub {
        owner = "PatrickF1";
        repo = "fzf.fish";
        rev = "8920367cf85eee5218cc25a11e209d46e2591e7a";
        hash = "sha256-T8KYLA/r/gOKvAivKRoeqIwE2pINlxFQtZJHpOy9GMM=";
      };
    }];
  };
}
