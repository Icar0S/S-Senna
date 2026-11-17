#!/usr/bin/env bash
# Roda o JOGO a partir do código-fonte.
# Procura o Godot na variável GODOT ou no PATH. Argumentos extras vão para o Godot.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../ci/_common.sh"
find_godot

if [ ! -d "$GODOT_PROJECT/.godot" ]; then
  info "Primeira execução: importando o projeto (pode levar um minuto)..."
  import_project
fi

exec "$GODOT_BIN" --path "$GODOT_PROJECT" "$@"
