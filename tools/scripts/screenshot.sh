#!/usr/bin/env bash
# Captura uma cena em PNG, para conferência visual (inclusive em máquinas sem GPU/tela).
#
# Uso: tools/scripts/screenshot.sh <cena> <saida.png> [largura altura] [-- argumentos da cena]
#   <cena>   res://game/main_menu/main_menu.tscn, ou o caminho do arquivo (godot/game/...)
#   Exemplo: tools/scripts/screenshot.sh res://game/sandbox/showroom_sandbox.tscn pearl.png -- --showroom-finish=pearl
#
# Variáveis: CAPTURE_FRAMES (quadros de espera; padrão 30)
#            RENDERING_METHOD (padrão gl_compatibility; use forward_plus numa máquina com GPU)
#
# Sem tela (CI, nuvem): usa o xvfb-run com renderização por software (Mesa).
#   Pacotes (Debian/Ubuntu): sudo apt-get install -y xvfb libgl1-mesa-dri
# Com tela (Windows, Linux desktop): abre uma janela por um instante.
# Falha se algum shader não compilar ou houver erro de script ("SHADER ERROR", "SCRIPT ERROR").
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../ci/_common.sh"

positional=()
scene_args=()
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--" ]; then
    shift
    scene_args=("$@")
    break
  fi
  positional+=("$1")
  shift
done

if [ "${#positional[@]}" -ne 2 ] && [ "${#positional[@]}" -ne 4 ]; then
  sed -n '2,6p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi

scene="${positional[0]}"
output="${positional[1]}"
width="${positional[2]:-1280}"
height="${positional[3]:-720}"
frames="${CAPTURE_FRAMES:-30}"
rendering="${RENDERING_METHOD:-gl_compatibility}"

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
  --rendering-method "$rendering" --audio-driver Dummy
  --windowed --resolution "${width}x${height}"
  res://core/debug/capture.tscn --
  "--capture-scene=$scene" "--capture-out=$(native_path "$output")" "--capture-frames=$frames"
  ${scene_args[@]+"${scene_args[@]}"})

log_file="$(mktemp)"
status=0
if [ "$(uname -s)" = "Linux" ] && [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
  command -v xvfb-run > /dev/null 2>&1 \
    || die "Sem tela e sem xvfb-run. Instale: sudo apt-get install -y xvfb libgl1-mesa-dri"
  xvfb-run --auto-servernum --server-args="-screen 0 ${width}x${height}x24" "${cmd[@]}" > "$log_file" 2>&1 || status=$?
else
  "${cmd[@]}" > "$log_file" 2>&1 || status=$?
fi

if grep -E "SHADER ERROR|Shader compilation failed|SCRIPT ERROR" "$log_file" > /dev/null; then
  cat "$log_file" >&2
  rm -f "$log_file"
  die "Erro de shader ou de script durante a captura ($rendering)."
fi
grep -E "\[(INFO|WARN|ERROR)\]|ERROR:" "$log_file" | tail -n 20 || true
rm -f "$log_file"

[ "$status" -eq 0 ] || die "A captura falhou (código $status)."
[ -s "$output" ] || die "A captura não gerou $output."
info "Captura salva em $output ($rendering)"
