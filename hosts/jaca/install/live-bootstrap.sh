#!/usr/bin/env bash
# Prepara o ISO minimal do NixOS para ser operado por SSH a partir do Mac.
#
# Uso no live USB (pendrive Ventoy montado em /mnt):
#   sudo mount -o ro /dev/disk/by-label/VENTOY /mnt
#   sudo bash /mnt/jaca/live-bootstrap.sh
#
# Lê as chaves públicas de authorized_keys, ao lado deste script.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

here="$(cd "$(dirname "$0")" && pwd)"
keys="$here/authorized_keys"

if [[ ! -s $keys ]]; then
  echo "ERRO: $keys não encontrado ou vazio." >&2
  exit 1
fi

# 1. Rede. Cabo costuma subir sozinho; Wi-Fi precisa do nmtui.
online() { ping -c1 -W3 1.1.1.1 >/dev/null 2>&1; }
until online; do
  echo
  echo "Sem internet. Abrindo nmtui: escolha 'Activate a connection' e conecte no Wi-Fi."
  read -rp "Enter para abrir (ou Ctrl+C para sair)... " _
  nmtui || true
done
echo "Rede OK."

# 2. Chaves do Mac para root e nixos.
for home in /root /home/nixos; do
  install -d -m 700 "$home/.ssh"
  install -m 600 "$keys" "$home/.ssh/authorized_keys"
done
chown -R nixos:users /home/nixos/.ssh

# 3. sshd não sobe sozinho no ISO.
systemctl start sshd

# 4. Mantém a máquina acordada mesmo com a tampa fechada.
systemctl stop jaca-keep-awake >/dev/null 2>&1 || true
systemd-run --unit=jaca-keep-awake --quiet \
  systemd-inhibit --what=sleep:idle:handle-lid-switch \
  --who=jaca-bootstrap --why="instalação via SSH" "$(command -v sleep)" infinity

# 5. Console sem apagar a tela, para os screenshots fazerem sentido.
setterm --blank 0 --powerdown 0 --term linux </dev/tty1 >/dev/tty1 2>/dev/null || true

echo
echo "=============================================="
echo " SSH pronto. Endereços desta máquina:"
ip -4 -br addr show scope global | awk '{print "   " $1 "  ->  " $3}'
echo
echo " No Mac:  ssh -i ~/.ssh/id_ed25519_jaca root@<IP>"
echo "=============================================="
