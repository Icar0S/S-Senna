#!/usr/bin/env bash
# Valida o conteúdo em JSON: sintaxe de todo .json e JSON Schemas (schemas/) com o
# check-jsonschema. Requer: pip install -r tools/ci/requirements.txt
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# Escolhe um Python 3.9+, de preferência um que já tenha o check-jsonschema instalado
# (no Windows, "python3" pode ser só o atalho da Microsoft Store; por isso testamos de verdade).
python_bin=""
fallback=""
for candidate in python3 python; do
  if "$candidate" -c "import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)" > /dev/null 2>&1; then
    [ -n "$fallback" ] || fallback="$candidate"
    if "$candidate" -c "import check_jsonschema" > /dev/null 2>&1; then
      python_bin="$candidate"
      break
    fi
  fi
done
python_bin="${python_bin:-$fallback}"
[ -n "$python_bin" ] || die "Python 3.9+ não encontrado (necessário para validar o conteúdo)."

PYTHONUTF8=1 "$python_bin" "$(native_path "$REPO_ROOT/tools/ci/validate_content.py")" "$(native_path "$REPO_ROOT")"
