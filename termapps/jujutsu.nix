{ config, ... }:

{
  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = config.userdata.name;
        email = config.userdata.email;
      };
      ui = {
        default-command = "log";
        pager = "less -FRX";
      };
    };
  };
}
