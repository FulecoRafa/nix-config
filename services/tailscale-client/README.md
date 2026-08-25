# Tailscale client

O Nix mantém `tailscaled`, a interface e as regras de rede. Depois do primeiro
rebuild, autentique o computador uma única vez:

```sh
sudo tailscale up
```

O login abre uma URL para associar o Jaca ao tailnet. O estado fica em
`/var/lib/tailscale` e sobrevive a rebuilds e reinicializações. Para conferir:

```sh
tailscale status
tailscale ip
```

Não há `authKeyFile`: uma chave no Nix store seria inadequada e uma chave via
sops só se justifica se futuramente quisermos reinstalação sem login manual.
