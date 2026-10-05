{ pkgs, ... }:

# Mensageiros como web apps (Helium em modo --app), com ícones do Papirus.
let
  icon = name: "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/apps/${name}.svg";
in
{
  localWebApps = {
    enable = true;
    apps = {
      whatsapp = {
        name = "WhatsApp";
        url = "https://web.whatsapp.com";
        icon = icon "whatsapp";
        comment = "WhatsApp Web";
        categories = [
          "Network"
          "InstantMessaging"
        ];
      };
      telegram = {
        name = "Telegram";
        url = "https://web.telegram.org/a/";
        icon = icon "telegram";
        comment = "Telegram Web";
        categories = [
          "Network"
          "InstantMessaging"
        ];
      };
    };
  };
}
