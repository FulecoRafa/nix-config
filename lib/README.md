# fulecoLib

Funções compartilhadas pela configuração. A biblioteca é exposta como
`lib` pela flake e injetada nos módulos como o argumento `fulecoLib`, sem
substituir a `lib` do nixpkgs.

## Aplicações web locais

Uma aplicação pode ser declarada com o construtor `mkWebApp`:

```nix
{ fulecoLib, ... }:

{
  localWebApps.apps.meu-app = fulecoLib.mkWebApp "Meu App" {
    url = "http://127.0.0.1:8080";
    service = "meu-app.service";
    icon = "meu-app";
    categories = [ "Utility" ];

    healthCheck.url = "http://127.0.0.1:8080/api/health";
  };
}
```

O módulo usa internamente:

- `types.webApp`: tipo, defaults e validação da declaração;
- `mkBrowserCommand`: monta o comando sem interpretação acidental pelo shell;
- `mkWebAppLauncher`: inicia o serviço, espera o health check e abre o browser;
- `mkDesktopEntry`: produz a entrada em `xdg.dataFile`.

O navegador é configurado separadamente. `executable` deve conter somente o
caminho do programa; cada argumento ocupa uma posição em `arguments`:

```nix
localWebApps.browser = {
  package = pkgs.chromium;
  executable = lib.getExe pkgs.chromium;
  arguments = [ "--app={{url}}" ];
};
```
