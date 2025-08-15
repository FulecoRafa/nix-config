{pkgs, ...}:

# This is a bundle of packages that will normally go in the cli without much change.
# Set these here to extend user packages.
{
  imports = [
    ./zellij
    ./fish
    ./helix
    ./fastfetch
    ./zoxide.nix
    ./jujutsu.nix
  ];

  home.packages = with pkgs; [
      bat         # cat
      eza         # ls
      yazi        # File Manager
      ripgrep     # grep
      ripgrep-all # grep, but with pdf and other files
      fzf         # fuzzy search
      fend        # calculator in terminal
      jq          # json
      scooter     # Find and replace
      fd          # find
  ];
}
