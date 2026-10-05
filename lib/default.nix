{ lib }:

let
  types = import ./types.nix { inherit lib; };
  webApp = import ./web-app.nix { inherit lib; };
in
{
  inherit types;
  inherit (webApp)
    mkBrowserCommand
    mkWebApp
    mkWebAppLauncher
    ;

  mkDesktopEntry = import ./desktop-entry.nix { inherit lib; };
  mkLiveConfigPackage = import ./live-config.nix { };
}
