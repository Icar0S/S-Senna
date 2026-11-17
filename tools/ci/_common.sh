#!/usr/bin/env bash
# Funções compartilhadas pelos scripts de tools/ci e tools/scripts.
# Uso: source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# shellcheck disable=SC2034  # variáveis usadas por quem faz o source
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_PROJECT="$REPO_ROOT/godot"
GODOT_VERSION_WANTED="$(tr -d '[:space:]' < "$REPO_ROOT/.godot-version")"

info() { printf '%s\n' "$*"; }
warn() { printf 'AVISO: %s\n' "$*" >&2; }
die() {
  printf 'ERRO: %s\n' "$*" >&2
  exit 1
}

# Converte um caminho para o formato do sistema (no Git Bash do Windows: C:/...).
native_path() {
  if command -v cygpath > /dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s\n' "$1"
  fi
}

# Procura o Godot e grava o caminho em GODOT_BIN.
# Ordem: variável GODOT, variável GODOT_BIN, `godot`/`godot4` no PATH, ~/.local/bin/godot.
find_godot() {
  local candidate="${GODOT:-${GODOT_BIN:-}}"
  if [ -n "$candidate" ]; then
    if [ ! -f "$candidate" ] && ! command -v "$candidate" > /dev/null 2>&1; then
      die "A variável GODOT/GODOT_BIN aponta para '$candidate', que não existe."
    fi
  elif command -v godot > /dev/null 2>&1; then
    candidate="godot"
  elif command -v godot4 > /dev/null 2>&1; then
    candidate="godot4"
  elif [ -x "$HOME/.local/bin/godot" ]; then
    candidate="$HOME/.local/bin/godot"
  else
    cat >&2 << EOF
ERRO: Godot não encontrado.

Instale o Godot $GODOT_VERSION_WANTED (versão padrão, sem .NET): https://godotengine.org/download
Depois, faça UMA destas opções:
  - coloque o executável no PATH com o nome "godot"; ou
  - defina a variável GODOT com o caminho completo do executável, por exemplo:
      export GODOT="\$HOME/Downloads/Godot_v$GODOT_VERSION_WANTED-stable_linux.x86_64"
No Linux/CI você também pode rodar: tools/ci/install_godot.sh
EOF
    exit 1
  fi
  GODOT_BIN="$candidate"

  local version
  version="$("$GODOT_BIN" --version 2> /dev/null | tr -d '\r' | head -n 1)"
  case "$version" in
    "$GODOT_VERSION_WANTED".*) ;;
    "") warn "Não consegui ler a versão do Godot em '$GODOT_BIN'." ;;
    *) warn "Godot $version encontrado, mas o projeto usa $GODOT_VERSION_WANTED (.godot-version)." ;;
  esac
}

# Importa o projeto (gera godot/.godot). Necessário antes de rodar testes ou o jogo
# em um clone novo: sem isso o Godot não conhece as classes com `class_name`.
import_project() {
  local log
  log="$("$GODOT_BIN" --headless --path "$GODOT_PROJECT" --import 2>&1)" || {
    printf '%s\n' "$log" >&2
    die "A importação do projeto falhou."
  }
  if printf '%s\n' "$log" | grep -E "SCRIPT ERROR|Parse Error|Failed to load script" > /dev/null; then
    printf '%s\n' "$log" >&2
    die "A importação do projeto encontrou erros de script."
  fi
}
