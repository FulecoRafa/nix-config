# Live Config

Algumas aplicações precisam escrever na própria configuração durante testes.
O Home Manager normalmente aponta esses arquivos para o Nix store, que é
somente leitura. Este módulo cria, somente para entradas autorizadas, uma
cópia gravável em `~/.local/state/live-config/worktrees` e faz o diretório
usado pela aplicação apontar para ela. As entradas são diretórios para que
aplicações que salvam arquivos por substituição atômica não quebrem o link
gerenciado pelo Home Manager.

A cópia é reinicializada a partir da configuração declarativa no primeiro
login/ativação de cada boot. Uma nova execução do Home Manager no mesmo boot
não destrói testes em andamento.

## Comandos

```console
live-config list
live-config status [nome]
live-config diff <nome>
live-config reset <nome|--all>
live-config save <nome> [--repo <caminho>]
```

`reset` descarta a experiência e restaura o conteúdo da geração atual.
`save` exige confirmação, localiza a raiz com `jj root` e copia o resultado
para o único caminho do repositório autorizado pelo módulo. Remoções também
são promovidas, então o diff do Jujutsu é mostrado ao final. O comando não
cria commit nem aplica uma nova geração.

O diretório inteiro de configuração de uma aplicação só deve ser cadastrado
quando ele contiver exclusivamente preferências que podem entrar no
repositório. Diretórios que também guardam tokens, sessões, bancos de dados ou
cache devem ser divididos em entradas menores ou permanecer fora deste
mecanismo.

O primeiro consumidor é `quickshell`: seus arquivos QML podem ser alterados
diretamente em `~/.config/quickshell/fuleco` durante o boot e promovidos com:

```console
live-config save quickshell
```

## Declaração em módulos

O pacote e sua configuração mutável são declarados juntos no módulo da
aplicação:

```nix
home.packages = [
  (fulecoLib.mkLiveConfigPackage {
    package = pkgs.quickshell;
    name = "quickshell";
    source = ./quickshell;
    target = ".config/quickshell/fuleco";
    repositoryPath = "guiapps/hyprland/quickshell";
  })
];
```

`mkLiveConfigPackage` preserva o pacote e adiciona metadados que o módulo
`services.liveConfig` coleta. Portanto, não é necessário declarar novamente
`services.liveConfig.entries`. Esta opção continua disponível para uma
configuração que não corresponda a nenhum pacote.
