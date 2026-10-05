{
  lib,
  root,
  ...
}:

# jabuticaba — laptop Linux (ThinkPad T14 Gen 2i).
# Mesma composição de desktop do jaca; aqui ficam só o hardware físico, as
# otimizações de bateria e o acesso remoto.
{
  imports = [
    (root + /hosts/jaca)
    ./hardware.nix
    ./laptop.nix
  ];

  networking.hostName = lib.mkForce "jabuticaba";

  # Acesso a partir do caju (Mac), somente por chave.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users =
    let
      keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID5+3UZIHjeTErthrNYWAz0K0xjxamU6LnIABvMIKaJ5 fuleco@caju->jaca"
      ];
    in
    {
      root.openssh.authorizedKeys.keys = keys;
      fuleco.openssh.authorizedKeys.keys = keys;
    };

  home-manager.users.fuleco.hyprlandDesktop.monitors = [
    {
      name = "eDP-1";
      mode = "1920x1080@60";
      position = "0x0";
      scale = "1.25";
    }
  ];
}
