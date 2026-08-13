{ lib }:

{
  id,
  name,
  exec,
  icon ? null,
  comment ? null,
  categories ? [ "Utility" ],
  terminal ? false,
  startupNotify ? true,
}:

lib.nameValuePair "applications/${lib.strings.sanitizeDerivationName id}.desktop" {
  text = lib.generators.toINI { } {
    "Desktop Entry" = {
      Type = "Application";
      Name = name;
      Exec = exec;
      Terminal = terminal;
      Categories = lib.concatStringsSep ";" categories + ";";
      StartupNotify = startupNotify;
    }
    // lib.optionalAttrs (icon != null) { Icon = toString icon; }
    // lib.optionalAttrs (comment != null) { Comment = comment; };
  };
}
