{ pkgs, ... }:

# Tela de login gráfica: SDDM (Qt6) em Wayland com o tema astronaut,
# recolorido para o papel de parede.
let
  theme = pkgs.sddm-astronaut.override {
    themeConfig = {
      Background = "${pkgs.callPackage ./wallpaper/package.nix { }}";
      CropBackground = "true";
      HeaderText = "";
      Font = "Open Sans";
      FormPosition = "left";
      PartialBlur = "true";
      FormBackgroundColor = "#10163a";
      BackgroundColor = "#0a0e24";
      DimBackgroundColor = "#0a0e24";
      LoginFieldBackgroundColor = "#1f285c";
      PasswordFieldBackgroundColor = "#1f285c";
      LoginButtonBackgroundColor = "#ff7a29";
      HoverUserIconColor = "#ffae42";
      HoverPasswordIconColor = "#ffae42";
      HoverSystemButtonsIconsColor = "#ffae42";
      HoverSessionButtonTextColor = "#ffae42";
      HighlightBackgroundColor = "#ff7a29";
      HighlightBorderColor = "#ff7a29";
      DropdownSelectedBackgroundColor = "#1f285c";
      DropdownBackgroundColor = "#10163a";
      # Enter com a senha vazia autentica pela digital (ver fingerprint/).
      AllowEmptyPassword = "true";
    };
  };
in
{
  services.displayManager = {
    defaultSession = "hyprland-uwsm";
    sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm;
      wayland.enable = true;
      theme = "sddm-astronaut-theme";
      extraPackages = [ theme ];
    };
  };

  environment.systemPackages = [ theme ];
}
