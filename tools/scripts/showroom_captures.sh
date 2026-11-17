#!/usr/bin/env bash
# Captura o showroom com cada acabamento de pintura (e com faróis acesos), para
# conferir a pintura e provar que os shaders compilam.
#
# Uso: tools/scripts/showroom_captures.sh <pasta_de_saida>
# Variáveis: RENDERING_METHOD (padrão gl_compatibility), CAPTURE_FRAMES.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../ci/_common.sh"

[ "$#" -eq 1 ] || die "Uso: tools/scripts/showroom_captures.sh <pasta_de_saida>"
out_dir="$1"
mkdir -p "$out_dir"
scene="res://game/sandbox/showroom_sandbox.tscn"
shot="$REPO_ROOT/tools/scripts/screenshot.sh"
view=(--showroom-no-ui --showroom-yaw=35 --showroom-pitch=-10)

# Cor de cada acabamento (presets do pacote base).
declare -A colors=(
  [solid]=paint:base/vermelho_corrida
  [metallic]=paint:base/laranja_senna
  [pearl]=paint:base/branco_gelo
  [matte]=paint:base/preto_fosco
  [satin]=paint:base/grafite_acetinado
  [chrome]=paint:base/cromo
  [candy]=paint:base/azul_perolado
  [chameleon]=paint:base/camaleao_roxo
)

for finish in solid metallic pearl matte satin chrome candy chameleon; do
  bash "$shot" "$scene" "$out_dir/pintura_$finish.png" -- "${view[@]}" \
    "--showroom-finish=$finish" "--showroom-color=${colors[$finish]}" \
    --showroom-wheel=wheel:base/basica_5
done
bash "$shot" "$scene" "$out_dir/farois_acesos.png" -- --showroom-no-ui --showroom-yaw=15 \
  --showroom-pitch=-6 --showroom-lights
info "Capturas do showroom em $out_dir"
