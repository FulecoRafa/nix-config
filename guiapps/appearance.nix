{ lib, pkgs, ... }:

let
  font = "CaskaydiaCove Nerd Font";
  # Só as seções de cor ([ColorEffects:*], [Colors:*]); [General], [KDE] e
  # [WM] são escritas abaixo no kdeglobals.
  ayuMirageColors = builtins.head (lib.splitString "\n[General]" (builtins.readFile ./ayu-mirage.colors));
  ayuMirageGtk = pkgs.ayu-theme-gtk.overrideAttrs (old: {
    pname = "ayu-mirage-theme-gtk";
    postInstall = (old.postInstall or "") + ''
      cp -r $out/share/themes/Ayu-Darker $out/share/themes/Ayu-Mirage
      find $out/share/themes/Ayu-Mirage -type f -exec substituteInPlace {} \
        --replace-warn '#0a0e14' '#1f2430' \
        --replace-warn '#01060e' '#191e2a' \
        --replace-warn '#b3b1ad' '#cbccc6' \
        --replace-warn 'Ayu-Darker' 'Ayu-Mirage' \;
    '';
  });
in
{
  home.packages = [
    ayuMirageGtk
    pkgs.nerd-fonts.caskaydia-cove
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      monospace = [ font ];
      sansSerif = [ font ];
      serif = [ font ];
    };
  };

  gtk = {
    enable = true;
    font = {
      name = font;
      size = 11;
    };
    theme = {
      name = "Ayu-Mirage";
      package = ayuMirageGtk;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  # GTK4/libadwaita e o portal (org.freedesktop.appearance.color-scheme) leem
  # a preferência daqui, não do settings.ini.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Ayu-Mirage";
  };

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style = {
      name = "breeze";
      package = pkgs.kdePackages.breeze;
    };
  };

  # Fora do Plasma, o platform theme do KDE monta a paleta das seções
  # [Colors:*] do próprio kdeglobals (ColorScheme= sozinho não basta), então a
  # paleta Ayu Mirage vai inteira para lá também.
  xdg.dataFile."color-schemes/AyuMirage.colors".source = ./ayu-mirage.colors;
  xdg.configFile."kdeglobals".text = ayuMirageColors + ''

    [General]
    ColorScheme=AyuMirage
    Name=Ayu Mirage
    fixed=${font},11,-1,5,50,0,0,0,0,0
    font=${font},11,-1,5,50,0,0,0,0,0
    menuFont=${font},11,-1,5,50,0,0,0,0,0
    smallestReadableFont=${font},9,-1,5,50,0,0,0,0,0
    shadeSortColumn=true
    toolBarFont=${font},11,-1,5,50,0,0,0,0,0

    [KDE]
    LookAndFeelPackage=org.kde.breezedark.desktop
    contrast=4
    widgetStyle=Breeze

    [WM]
    activeBackground=31,36,48
    activeBlend=31,36,48
    activeForeground=203,204,198
    inactiveBackground=25,30,40
    inactiveBlend=25,30,40
    inactiveForeground=112,122,140
  '';
}
