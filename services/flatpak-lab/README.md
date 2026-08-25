# Flatpak Lab

Laboratório descartável para avaliar aplicativos sem promovê-los à
configuração permanente.

```sh
app-try org.gimp.GIMP
app-try https://flathub.org/apps/org.gimp.GIMP
app-try ~/Downloads/org.gimp.GIMP.flatpakref
```

O helper instala no escopo do usuário, mostra as permissões declaradas, abre o
app e, quando ele fecha, remove o app com `--delete-data` e limpa runtimes não
utilizados. Um serviço no próximo login recupera tentativas interrompidas.

Aplicativos que já estavam instalados antes do comando são apenas executados:
o laboratório não os marca nem os remove. A limpeza cobre os dados que o
Flatpak controla em `~/.var/app`; arquivos que o próprio usuário salvar fora do
sandbox por meio de um portal continuam sendo arquivos do usuário.

Se um experimento for aprovado, ele deve ser promovido separadamente para um
pacote do nixpkgs, um pacote próprio ou uma declaração Flatpak permanente.
