{ pkgs, ... }:

# Aplicativos que eram casks do Homebrew, mas têm pacote aarch64-darwin no
# nixpkgs. O nix-darwin os expõe em /Applications/Nix Apps.
{
  environment.systemPackages = with pkgs; [
    aerospace
    betterdisplay
    claude-code
    cmux
    dbeaver-bin
    discord
    ghostty-bin
    hidden-bar
    iina
    mediamate
    nerd-fonts.caskaydia-cove
    nerd-fonts.fira-code
    ngrok
    obsidian
    postman
    qbittorrent
    raycast
    shottr
    telegram-desktop
    vscode
    zed-editor
  ];
}
