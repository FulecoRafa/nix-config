{ pkgs, ... }:

let
  font = "CaskaydiaCove Nerd Font";
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
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style = {
      name = "breeze";
      package = pkgs.kdePackages.breeze;
    };
  };

  # Plasma/Qt lê o esquema em ~/.local/share/color-schemes e a seleção em
  # kdeglobals. A paleta abaixo é a Ayu Mirage oficial.
  xdg.dataFile."color-schemes/AyuMirage.colors".source = ./ayu-mirage.colors;
  xdg.configFile."kdeglobals".text = ''
    [General]
    ColorScheme=AyuMirage
    Name=Ayu Mirage
    fixed=${font},11,-1,5,50,0,0,0,0,0
    font=${font},11,-1,5,50,0,0,0,0,0
    menuFont=${font},11,-1,5,50,0,0,0,0,0
    smallestReadableFont=${font},9,-1,5,50,0,0,0,0,0
    toolBarFont=${font},11,-1,5,50,0,0,0,0,0

    [KDE]
    LookAndFeelPackage=org.kde.breezedark.desktop
    widgetStyle=Breeze
  '';
}
