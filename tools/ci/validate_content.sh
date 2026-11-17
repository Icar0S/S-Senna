#!/usr/bin/env bash
# Valida o conteúdo em JSON. Por enquanto confere só que todo .json é JSON válido;
# a validação contra os JSON Schemas (schemas/) entra na Etapa 01.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# No Windows, "python3" pode ser só o atalho da Microsoft Store; por isso testamos de verdade.
python_bin=""
for candidate in python3 python; do
  if "$candidate" -c "import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)" > /dev/null 2>&1; then
    python_bin="$candidate"
    break
  fi
done
[ -n "$python_bin" ] || die "Python 3.9+ não encontrado (necessário para validar o conteúdo)."

PYTHONUTF8=1 "$python_bin" "$(native_path "$REPO_ROOT/tools/ci/validate_content.py")" "$(native_path "$REPO_ROOT")"
