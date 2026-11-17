#!/usr/bin/env bash
# Gera os modelos procedurais (carro de teste das fixtures, protótipo do pacote base,
# aros e aerofólio universal) com tools/fixtures/make_test_car.gd.
# Depois de rodar, confira o resultado com: tools/ci/test.sh
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../ci/_common.sh"
find_godot
import_project

"$GODOT_BIN" --headless --path "$GODOT_PROJECT" -s "$(native_path "$REPO_ROOT/tools/fixtures/make_test_car.gd")"

info "== Reimportando os modelos gerados"
import_project
info "Pronto."
