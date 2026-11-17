#!/usr/bin/env bash
# Lint do GDScript: gdformat --check + gdlint em godot/ e tools/fixtures/ (addons/ fica de fora).
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

# GDScript do projeto e dos geradores de tools/fixtures.
targets=(godot tools/fixtures)

if [ "${1:-}" = "--fix" ]; then
  gdformat "${targets[@]}"
else
  info "== gdformat --check"
  gdformat --check "${targets[@]}"
fi

info "== gdlint"
gdlint "${targets[@]}"
