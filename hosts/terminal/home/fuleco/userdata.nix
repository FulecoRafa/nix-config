{ lib, ... }:

let
  inherit ( lib ) types;
in
{
  options.userdata = {
    name = lib.mkOption {
       type = types.str;
       description = "Full name, different from username";
     };
    email = lib.mkOption {
      type = types.strMatching (''^.+@.+$'');
      description = "Default user email";
    };
  };
}
