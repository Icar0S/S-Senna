#!/usr/bin/env bash
# Instala o .zip do add-on num perfil TEMPORÁRIO do Blender (não mexe no seu) e confere
# que ele registra os operadores e lê o conventions.json embutido no pacote.
#
# Uso: tools/blender/test_install.sh      (gera o .zip antes com build_extension.sh)
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../ci/_common.sh"
cd "$REPO_ROOT"

bash tools/blender/build_extension.sh
version="$(sed -n 's/^version = "\(.*\)"/\1/p' tools/blender/senna_carkit/blender_manifest.toml)"
zip_file="$REPO_ROOT/build/senna_carkit-$version.zip"

find_blender
profile="$(mktemp -d)"
trap 'rm -rf "$profile"' EXIT
export BLENDER_USER_RESOURCES
BLENDER_USER_RESOURCES="$(native_path "$profile")"

info "== Instalando $zip_file num perfil temporário"
"$BLENDER_BIN" -b --factory-startup --command extension install-file -r user_default --enable \
  "$(native_path "$zip_file")"
info "== Conferindo o add-on instalado"
"$BLENDER_BIN" -b --python-exit-code 1 -P "$(native_path "$REPO_ROOT/tools/blender/tests/check_installed.py")"
