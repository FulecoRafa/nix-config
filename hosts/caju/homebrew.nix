{ ... }:

# Homebrew fica somente como backend declarativo para software sem pacote Nix
# adequado no macOS. Fórmulas e casks fora destas listas são removidos na
# ativação, depois que a nova closure Nix já foi construída.
{
  homebrew = {
    enable = true;
    user = "fuleco";

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "uninstall";
    };

    taps = [
      "arthur-ficial/tap"
      "nubjs/tap"
    ];

    brews = [
      "arm-linux-gnueabihf-binutils"
      "arthur-ficial/tap/apfel"
      "nubjs/tap/nub"
      "python@3.10"
      "ratty"
    ];

    casks = [
      "background-music"
      "bettertouchtool"
      "claude"
      "dockdoor"
      "dropzone"
      "flux-markdown"
      "helium"
      "helium-browser"
      "moom"
      "obs"
      "openzfs"
      "qmk-toolbox"
      "rive"
      "steam"
      "zen"
    ];
  };
}
