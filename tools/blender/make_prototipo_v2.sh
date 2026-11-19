#!/usr/bin/env bash
# Regera o protótipo do pacote base (car:base/prototipo) com o add-on S-Senna CarKit:
# modela, valida, exporta model.glb + carkit_manifest.json e atualiza o car.json.
#
# Uso: tools/blender/make_prototipo_v2.sh [--blend <arquivo.blend>]
#   --blend   também salva a cena do Blender (para abrir e ver como foi montado)
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../ci/_common.sh"
cd "$REPO_ROOT"

find_blender
PYTHONUTF8=1 "$BLENDER_BIN" -b --factory-startup --python-exit-code 1 \
  -P "$(native_path "$REPO_ROOT/tools/blender/make_prototipo_v2.py")" -- "$@"

find_godot
info "== Reimportando o modelo no Godot"
import_project
info "Pronto. Confira com: tools/ci/test.sh"
