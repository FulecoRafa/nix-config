#!/usr/bin/env bash
# Tira um screenshot da tela do jaca e copia para o Mac.
#
# Uso: hosts/jaca/install/shot.sh <host> [arquivo.png]
#
# No live USB (console) usa ffmpeg sobre /dev/fb0. Com Hyprland rodando usa
# grim na sessão Wayland do usuário fuleco.
set -euo pipefail

host="${1:?uso: shot.sh <host> [arquivo.png]}"
out="${2:-jaca-$(date +%Y%m%d-%H%M%S).png}"
ssh_opts=(-i ~/.ssh/id_ed25519_jaca -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

ssh "${ssh_opts[@]}" "root@$host" bash -s <<'EOF'
set -euo pipefail
bin() {
  command -v "$2" 2>/dev/null && return
  for out in $(nix --extra-experimental-features 'nix-command flakes' build --quiet --no-link \
    --print-out-paths "nixpkgs#$1" 2>/dev/null); do
    [[ -x $out/bin/$2 ]] && echo "$out/bin/$2" && return
  done
  echo "$2 não encontrado em nixpkgs#$1" >&2
  return 1
}

runtime=/run/user/$(id -u fuleco 2>/dev/null || echo none)
socket=$(ls "$runtime"/wayland-* 2>/dev/null | grep -v '\.lock$' | head -1 || true)

rm -f /tmp/jaca-shot.png
if [[ -n $socket ]]; then
  sudo -u fuleco env XDG_RUNTIME_DIR="$runtime" WAYLAND_DISPLAY="$(basename "$socket")" \
    "$(bin grim grim)" /tmp/jaca-shot.png
else
  "$(bin ffmpeg-headless ffmpeg)" -loglevel error -f fbdev -i /dev/fb0 -frames:v 1 -pix_fmt rgb24 /tmp/jaca-shot.png
fi
EOF

scp "${ssh_opts[@]}" "root@$host:/tmp/jaca-shot.png" "$out" >/dev/null
echo "$out"
