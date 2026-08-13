{ lib }:

let
  replaceUrl = url: lib.replaceStrings [ "{{url}}" ] [ url ];
  mkBrowserCommand =
    {
      executable,
      arguments ? [ ],
      url,
    }:
    lib.escapeShellArgs ([ executable ] ++ map (replaceUrl url) arguments);
in
{
  # Construtor pequeno para manter definições de aplicações legíveis. Os
  # defaults e a validação continuam pertencendo ao tipo do módulo.
  mkWebApp = name: app: app // { inherit name; };

  inherit mkBrowserCommand;

  mkWebAppLauncher =
    pkgs:
    {
      id,
      app,
      browser,
    }:
    let
      launcherName = "local-web-app-${lib.strings.sanitizeDerivationName id}";
      browserCommand = mkBrowserCommand {
        inherit (browser) executable arguments;
        inherit (app) url;
      };
    in
    pkgs.writeShellApplication {
      name = launcherName;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.curl
      ]
      ++ lib.optional (app.service != null) pkgs.systemd;
      text = ''
        ${lib.optionalString (app.service != null) ''
          systemctl --user start ${lib.escapeShellArg app.service}
        ''}

        ${lib.optionalString app.healthCheck.enable ''
          deadline=$((SECONDS + ${toString app.healthCheck.timeoutSeconds}))
          until curl --fail --silent \
            --max-time 2 ${lib.escapeShellArg app.healthCheck.url} >/dev/null; do
            if [ "$SECONDS" -ge "$deadline" ]; then
              printf '%s\n' ${lib.escapeShellArg "${id}: serviço não respondeu em ${app.healthCheck.url}"} >&2
              exit 1
            fi
            sleep ${toString app.healthCheck.intervalSeconds}
          done
        ''}

        exec ${browserCommand}
      '';
    };
}
