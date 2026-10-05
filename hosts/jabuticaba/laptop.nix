{ ... }:

# Energia e periféricos próprios de laptop.
{
  services = {
    power-profiles-daemon.enable = true;
    thermald.enable = true;
    upower.enable = true;

    # Firmware da Lenovo via LVFS (`fwupdmgr update`).
    fwupd.enable = true;

    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
    };
  };
}
