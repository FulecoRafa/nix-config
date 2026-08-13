{ root, ... }:

# Aplicações e aparência comuns a todos os hosts com ambiente gráfico.
{
  imports = [
    ./appearance.nix
    ./fuchico.nix
    ./helium.nix
    (root + /termapps/ghostty)
    (root + /guiapps/espanso)
  ];
}
