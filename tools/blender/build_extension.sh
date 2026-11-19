#!/usr/bin/env bash
# Gera o .zip instalável do add-on (Blender Extension): build/senna_carkit-<versão>.zip
#
# Copia godot/core/content/conventions.json para dentro do add-on (a mesma fonte de
# slots, materiais e soquetes do jogo) e empacota com `blender --command extension build`,
# que também confere o blender_manifest.toml. Sem Blender, empacota com Python.
#
# Uso: tools/blender/build_extension.sh
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../ci/_common.sh"
cd "$REPO_ROOT"

addon_dir="tools/blender/senna_carkit"
version="$(sed -n 's/^version = "\(.*\)"/\1/p' "$addon_dir/blender_manifest.toml")"
[ -n "$version" ] || die "Versão não encontrada em $addon_dir/blender_manifest.toml"
zip_file="build/senna_carkit-$version.zip"

mkdir -p build
rm -f "$zip_file"
cp godot/core/content/conventions.json "$addon_dir/conventions.json"
find "$addon_dir" -name "__pycache__" -type d -prune -exec rm -rf {} +

if (find_blender) > /dev/null 2>&1; then
  find_blender
  "$BLENDER_BIN" --factory-startup --command extension build \
    --source-dir "$(native_path "$REPO_ROOT/$addon_dir")" \
    --output-filepath "$(native_path "$REPO_ROOT/$zip_file")"
else
  warn "Blender não encontrado: empacotando com Python (sem conferir o manifesto)."
  find_python
  "$PYTHON_BIN" "$(native_path "$REPO_ROOT/tools/blender/zip_addon.py")" "$addon_dir" "$zip_file"
fi

[ -f "$zip_file" ] || die "O pacote não foi gerado."
info "Add-on empacotado: $zip_file (instale arrastando o .zip para a janela do Blender)"
