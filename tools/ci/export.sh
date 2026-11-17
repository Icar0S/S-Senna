#!/usr/bin/env bash
# Exporta o Jogo e o Studio e confere o conteúdo das builds.
#
# Uso: tools/ci/export.sh [linux|windows|all]     (padrão: a plataforma desta máquina)
#
# Saída em build/<plataforma>/. Requer os export templates do Godot
# (CI/Linux: tools/ci/install_godot.sh --templates; no editor: Editor > Gerenciar modelos de exportação).
#
# Conferência (só para a plataforma desta máquina, pois precisa executar a build):
# roda cada executável com `-- --self-check` e verifica que
#   - o JSON de conteúdo (res://content/packs/base/pack.json) está na build, o ContentDB
#     carrega o pacote base sem erros e o modelo do carro protótipo abre;
#   - a build do Jogo NÃO contém studio/; a do Studio contém;
#   - nenhuma build contém tests/.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
find_godot

case "$(uname -s)" in
  Linux) host_platform="linux" ;;
  MINGW* | MSYS* | CYGWIN*) host_platform="windows" ;;
  *) host_platform="" ;;
esac

target="${1:-$host_platform}"
case "$target" in
  linux | windows) platforms=("$target") ;;
  all) platforms=(linux windows) ;;
  *) die "Uso: tools/ci/export.sh [linux|windows|all]" ;;
esac

build_dir="$REPO_ROOT/build"

# export_one <preset> <arquivo de saída>
export_one() {
  local preset="$1" output="$2"
  mkdir -p "$(dirname "$output")"
  rm -f "$output"
  info "== Exportando \"$preset\" -> ${output#"$REPO_ROOT"/}"
  local log
  log="$("$GODOT_BIN" --headless --path "$GODOT_PROJECT" --export-release "$preset" "$(native_path "$output")" 2>&1)" || {
    printf '%s\n' "$log" >&2
    die "A exportação de \"$preset\" falhou."
  }
  if [ ! -s "$output" ]; then
    printf '%s\n' "$log" >&2
    die "A exportação de \"$preset\" não gerou $output (os export templates estão instalados?)."
  fi
}

# verify_build <executável> <modo esperado> <studio presente? true|false>
verify_build() {
  local binary="$1" expected_mode="$2" expected_studio="$3"
  local log_file line
  log_file="$(mktemp)"
  # --log-file: no Windows o executável exportado não escreve no terminal.
  "$binary" --headless --log-file "$(native_path "$log_file")" -- --self-check > /dev/null 2>&1 || true
  line="$(grep -a "^SELF_CHECK " "$log_file" | tr -d '\r' | head -n 1 || true)"
  rm -f "$log_file"
  [ -n "$line" ] || die "$(basename "$binary"): não respondeu ao --self-check."
  info "   $line"
  expect_field "$binary" "$line" mode "\"$expected_mode\""
  expect_field "$binary" "$line" content_json true
  expect_field "$binary" "$line" content_errors 0
  expect_field "$binary" "$line" probe_car_model true
  expect_field "$binary" "$line" studio_present "$expected_studio"
  expect_field "$binary" "$line" tests_present false
}

expect_field() {
  local binary="$1" line="$2" key="$3" value="$4"
  case "$line" in
    *"\"$key\":$value"*) ;;
    *) die "$(basename "$binary"): esperado \"$key\":$value no self-check." ;;
  esac
}

info "== Importando o projeto"
import_project

for platform in "${platforms[@]}"; do
  case "$platform" in
    linux)
      label="Linux"
      game_bin="$build_dir/linux/S-Senna.x86_64"
      studio_bin="$build_dir/linux/S-Senna-Studio.x86_64"
      ;;
    windows)
      label="Windows"
      game_bin="$build_dir/windows/S-Senna.exe"
      studio_bin="$build_dir/windows/S-Senna-Studio.exe"
      ;;
  esac
  export_one "Jogo - $label" "$game_bin"
  export_one "Studio - $label" "$studio_bin"

  if [ "$platform" = "$host_platform" ]; then
    info "== Conferindo as builds de $label"
    chmod +x "$game_bin" "$studio_bin" 2> /dev/null || true
    verify_build "$game_bin" game false
    verify_build "$studio_bin" studio true
  else
    info "== Builds de $label geradas (conferência do conteúdo só na própria plataforma)"
  fi
done

info "Exportação OK: $build_dir"
