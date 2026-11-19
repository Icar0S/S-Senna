#!/usr/bin/env bash
# Gera os modelos procedurais (carro de teste das fixtures,
# aros e aerofólio universal) com tools/fixtures/make_test_car.gd.
# O protótipo do pacote base vem do Blender: tools/blender/make_prototipo_v2.sh.
# Depois de rodar, confira o resultado com: tools/ci/test.sh
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../ci/_common.sh"
find_godot
import_project

"$GODOT_BIN" --headless --path "$GODOT_PROJECT" -s "$(native_path "$REPO_ROOT/tools/fixtures/make_test_car.gd")"

info "== Reimportando os modelos gerados"
import_project
info "Pronto."
