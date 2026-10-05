{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  fuchico = inputs.fuchico.packages.${system}.default;

  # O pnpm só baixa as dependências nativas da plataforma atual, então o hash
  # de pnpmDeps varia por sistema. O upstream declara um único hash; até ele
  # ter um por plataforma, corrigimos aqui os que divergem.
  pnpmDepsHashes = {
    x86_64-linux = "sha256-giBP1lyTxGpqI/Ja5bvcSGMPE3q9uYo26xR1/NX/zgI=";
  };
in
{
  home.packages = [
    (
      if pnpmDepsHashes ? ${system} then
        fuchico.overrideAttrs (old: {
          pnpmDeps = old.pnpmDeps.overrideAttrs { outputHash = pnpmDepsHashes.${system}; };
        })
      else
        fuchico
    )
  ];
}
