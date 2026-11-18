#!/usr/bin/env bash
# Testes do add-on S-Senna CarKit.
#
# Uso: tools/blender/run_tests.sh          testes puros (Python) + testes no Blender headless
#      tools/blender/run_tests.sh --pure   só os testes puros (não precisa do Blender)
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../ci/_common.sh"
cd "$REPO_ROOT"

find_python
info "== Testes puros (validador, nomes, geometria, manifesto, update_car_json)"
PYTHONUTF8=1 "$PYTHON_BIN" -m unittest discover -s tools/blender/tests -p "test_pure.py"

if [ "${1:-}" = "--pure" ]; then
  exit 0
fi

find_blender
info "== Testes no Blender ($BLENDER_BIN)"
PYTHONUTF8=1 "$BLENDER_BIN" -b --factory-startup --python-exit-code 1 \
  -P "$(native_path "$REPO_ROOT/tools/blender/tests/run_tests.py")"
