#!/usr/bin/env bash
# Lint do GDScript: gdformat --check + gdlint em godot/ (addons/ fica de fora).
# Requer o gdtoolkit: pip install -r tools/ci/requirements.txt
#
# Uso: tools/ci/lint.sh          confere
#      tools/ci/lint.sh --fix    formata os arquivos com o gdformat e depois roda o gdlint
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

for tool in gdformat gdlint; do
  command -v "$tool" > /dev/null 2>&1 \
    || die "'$tool' não encontrado. Instale com: pip install -r tools/ci/requirements.txt"
done

# As pastas excluídas (addons, .godot) ficam em gdformatrc e gdlintrc, lidos da raiz.
cd "$REPO_ROOT"

if [ "${1:-}" = "--fix" ]; then
  gdformat godot
else
  info "== gdformat --check"
  gdformat --check godot
fi

info "== gdlint"
gdlint godot
