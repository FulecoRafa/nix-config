{ config, ... }:

# Digital no login, no sudo e no hyprlock. Sem leitor, o pam_fprintd não acha
# dispositivo e a autenticação cai direto na senha; nada muda nessas máquinas.
# Cadastro: `fprintd-enroll` (e `fprintd-verify` para testar).
{
  services.fprintd.enable = true;

  # No login (SDDM inclui esta pilha) a senha vem primeiro: digitar a senha
  # entra sem esperar o leitor, e Enter com o campo vazio pede a digital.
  # A ordem padrão travaria a senha até o pam_fprintd expirar.
  security.pam.services.login.rules.auth.fprintd.order =
    config.security.pam.services.login.rules.auth.unix.order + 10;

  # sudo e polkit pedem a digital primeiro. Sem esperar o padrão de 30 s:
  # depois de 10 s ou 2 leituras erradas, cai para a senha.
  security.pam.services.sudo.rules.auth.fprintd.settings = {
    max-tries = 2;
    timeout = 10;
  };
  security.pam.services.polkit-1.rules.auth.fprintd.settings = {
    max-tries = 2;
    timeout = 10;
  };
}
