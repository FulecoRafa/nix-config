{
  lib,
  pkgs,
  root,
  ...
}:

{
  imports = [
    (root + /termapps/cli_utils.bundle.nix)
    (root + /termapps/nushell)
    (root + /hosts/terminal/home/fuleco/userdata.nix)
  ];

  userdata = {
    name = "FulecoRafa";
    email = "ra.pha@live.com";
  };

  home = {
    username = "fuleco";
    homeDirectory = "/Users/fuleco";
    stateVersion = "25.05";
    # Ambos os inputs seguem seus branches de desenvolvimento; os números de
    # release podem divergir mesmo compartilhando exatamente o mesmo nixpkgs.
    enableNixpkgsReleaseCheck = false;
    sessionVariables = {
      EDITOR = "hx";
      COLORTERM = "truecolor";
    };

    # Fórmulas explicitamente instaladas no Homebrew que têm equivalente
    # funcional no nixpkgs para Apple Silicon.
    packages = with pkgs; [
      awscli2
      bash
      bat
      binutils
      biome
      btop
      bun
      cargo
      chafa
      cmatrix
      cocoapods
      emscripten
      expat
      eza
      fastfetch
      fd
      ffmpeg
      fish
      fnm
      fzf
      gh
      glow
      gnugrep
      gnupg
      go
      go-blueprint
      golangci-lint
      gobject-introspection
      gopls
      gum
      hugo
      imagemagick
      inetutils # telnet
      jdk
      jjui
      just
      lazygit
      libadwaita
      libpq
      libtool
      lua
      mise
      mpv
      mqttx-cli
      neovim
      nmap
      nodejs
      openmpi
      openssl
      pipx
      pkg-config
      pmix
      pnpm
      python311
      python312
      python312Packages.pycairo
      python312Packages.pygobject3
      rio
      ripgrep
      ruby
      rust-analyzer
      rustc
      rustup
      sketchybar
      starship
      tailscale
      terraform
      tetris
      tinygo
      typst
      uv
      watch
      watchexec
      yazi
      zig
      zls
    ];
  };

  programs = {
    home-manager.enable = true;
    helix = {
      defaultEditor = true;
      # A branch personalizada de Helix usada no Linux referencia hoje uma
      # gramática removida do GitHub. Caju usa o pacote estável do nixpkgs.
      package = lib.mkForce pkgs.helix;
    };
  };
}
