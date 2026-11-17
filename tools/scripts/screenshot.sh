#!/usr/bin/env bash
# Captura uma cena em PNG, para conferência visual (inclusive em máquinas sem GPU/tela).
#
# Uso: tools/scripts/screenshot.sh <cena> <saida.png> [largura altura]
#   <cena>   res://game/main_menu/main_menu.tscn, ou o caminho do arquivo (godot/game/...)
#
# Variáveis: CAPTURE_FRAMES (quadros de espera antes da captura; padrão 30).
#
# Sem tela (CI, nuvem): usa o xvfb-run com renderização por software (Mesa).
#   Pacotes (Debian/Ubuntu): sudo apt-get install -y xvfb libgl1-mesa-dri
# Com tela (Windows, Linux desktop): abre uma janela por um instante.
# Sempre usa o modo Compatibility (OpenGL), o único que funciona sem GPU.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../ci/_common.sh"

if [ "$#" -ne 2 ] && [ "$#" -ne 4 ]; then
  sed -n '2,5p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi

scene="$1"
output="$2"
width="${3:-1280}"
height="${4:-720}"
frames="${CAPTURE_FRAMES:-30}"

# Aceita res://..., godot/caminho/cena.tscn ou caminho/cena.tscn (relativo a godot/).
case "$scene" in
  res://*) ;;
  *)
    scene="${scene//\\//}"
    scene="${scene#./}"
    scene="res://${scene#godot/}"
    ;;
esac
scene_file="$GODOT_PROJECT/${scene#res://}"
[ -f "$scene_file" ] || die "Cena não encontrada: $scene_file"

# Caminho absoluto de saída (o Godot roda com --path godot, então relativo não serve).
mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"
rm -f "$output"

find_godot
if [ ! -d "$GODOT_PROJECT/.godot" ]; then
  import_project
fi

cmd=("$GODOT_BIN" --path "$GODOT_PROJECT"
  --rendering-method gl_compatibility --audio-driver Dummy
  --windowed --resolution "${width}x${height}"
  res://core/debug/capture.tscn --
  "--capture-scene=$scene" "--capture-out=$(native_path "$output")" "--capture-frames=$frames")

status=0
if [ "$(uname -s)" = "Linux" ] && [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
  command -v xvfb-run > /dev/null 2>&1 \
    || die "Sem tela e sem xvfb-run. Instale: sudo apt-get install -y xvfb libgl1-mesa-dri"
  xvfb-run --auto-servernum --server-args="-screen 0 ${width}x${height}x24" "${cmd[@]}" || status=$?
else
  "${cmd[@]}" || status=$?
fi

[ "$status" -eq 0 ] || die "A captura falhou (código $status)."
[ -s "$output" ] || die "A captura não gerou $output."
info "Captura salva em $output"
