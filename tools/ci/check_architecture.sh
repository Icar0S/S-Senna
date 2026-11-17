#!/usr/bin/env bash
# Confere as regras de dependência de docs/plano/02-arquitetura.md §4:
#
#   core/   -> só core/ e addons/  (nada de game/, studio/ nem GameSession)
#   game/   -> core/, ui/, content/ (nada de studio/)
#   studio/ -> core/, ui/, content/ e, de game/, apenas game/sandbox/ (test drive)
#
# Uso: tools/ci/check_architecture.sh [pasta_do_projeto_godot]
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

project_dir="${1:-$GODOT_PROJECT}"
[ -d "$project_dir" ] || die "Pasta não encontrada: $project_dir"

# Arquivos que podem conter referências (código, cenas, recursos, shaders, dados).
includes=(--include='*.gd' --include='*.tscn' --include='*.tres' --include='*.gdshader'
  --include='*.gdshaderinc' --include='*.cfg' --include='*.json')

violations=0

# check <pasta> <regex proibida> <explicação> [regex de exceção]
check() {
  local dir="$project_dir/$1" pattern="$2" reason="$3" allowed="${4:-}"
  [ -d "$dir" ] || return 0
  local matches
  matches="$(grep -rnE "${includes[@]}" -- "$pattern" "$dir" || true)"
  if [ -n "$allowed" ] && [ -n "$matches" ]; then
    # Remove as ocorrências permitidas e vê se a linha ainda viola a regra.
    matches="$(printf '%s\n' "$matches" | while IFS= read -r line; do
      if printf '%s\n' "$line" | sed -E "s#$allowed##g" | grep -qE -- "$pattern"; then
        printf '%s\n' "$line"
      fi
    done)"
  fi
  if [ -n "$matches" ]; then
    printf 'VIOLAÇÃO: %s\n' "$reason" >&2
    printf '%s\n' "$matches" | sed "s#^$project_dir/#  #" >&2
    violations=$((violations + 1))
  fi
}

check core 'res://game/' "core/ não pode depender de game/"
check core 'res://studio/' "core/ não pode depender de studio/"
check core '(^|[^A-Za-z0-9_])GameSession([^A-Za-z0-9_]|$)' "core/ não pode usar GameSession"
check game 'res://studio/' "game/ não pode depender de studio/"
check studio 'res://game/' "studio/ só pode usar game/sandbox/ (test drive)" 'res://game/sandbox/'

if [ "$violations" -gt 0 ]; then
  die "$violations regra(s) de arquitetura violada(s). Ver docs/plano/02-arquitetura.md §4."
fi
info "Arquitetura OK."
