#!/usr/bin/env bash
# Lint do GDScript (gdformat --check + gdlint em godot/ e tools/fixtures/; addons/ fica de fora)
# e do Python de tools/ (ruff check + ruff format --check, regras em ruff.toml).
# Requer: pip install -r tools/ci/requirements.txt
#
# Uso: tools/ci/lint.sh          confere
#      tools/ci/lint.sh --fix    formata (gdformat, ruff format) e depois roda os linters
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

for tool in gdformat gdlint ruff; do
  command -v "$tool" > /dev/null 2>&1 \
    || die "'$tool' não encontrado. Instale com: pip install -r tools/ci/requirements.txt"
done

# As pastas excluídas (addons, .godot) ficam em gdformatrc e gdlintrc, lidos da raiz.
cd "$REPO_ROOT"

# GDScript do projeto e dos geradores de tools/fixtures.
targets=(godot tools/fixtures)

if [ "${1:-}" = "--fix" ]; then
  gdformat "${targets[@]}"
  ruff format tools
  ruff check --fix tools
else
  info "== gdformat --check"
  gdformat --check "${targets[@]}"
  info "== ruff format --check"
  ruff format --check tools
fi

info "== gdlint"
gdlint "${targets[@]}"

info "== ruff check"
ruff check tools
