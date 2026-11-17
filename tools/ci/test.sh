#!/usr/bin/env bash
# Roda os testes gdUnit4 em modo headless.
#
# Uso: tools/ci/test.sh                              todos os testes de res://tests
#      tools/ci/test.sh -a res://tests/unit/test_log.gd   só um arquivo/pasta (argumentos do gdUnit4)
#
# Passos: 1) importa o projeto; 2) confere que o projeto inicia sem erros nem avisos;
#         3) roda o gdUnit4. Relatórios em godot/reports/.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
find_godot

info "== Importando o projeto"
import_project

info "== Iniciando o projeto (headless --quit): não pode haver erros nem avisos"
boot_log="$("$GODOT_BIN" --headless --path "$GODOT_PROJECT" --quit 2>&1)" || {
  printf '%s\n' "$boot_log" >&2
  die "O projeto não iniciou."
}
if printf '%s\n' "$boot_log" | grep -E "ERROR|WARNING" > /dev/null; then
  printf '%s\n' "$boot_log" >&2
  die "O projeto iniciou com erros ou avisos (veja acima)."
fi

info "== gdUnit4"
if [ "$#" -eq 0 ]; then
  set -- -a res://tests
fi
# -d ativa o depurador (o gdUnit4 precisa dele para detectar erros de script) e
# --remote-debug em uma porta inválida impede que o depurador interativo trave o
# terminal em um erro de script. É o mesmo truque do runtest.sh oficial; as duas
# linhas "ERROR: ... remote port/Remote Debugger" no início da saída são esperadas.
status=0
"$GODOT_BIN" --headless --path "$GODOT_PROJECT" -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode "$@" || status=$?

if [ "$status" -ne 0 ]; then
  die "Testes falharam (código $status). Relatório em godot/reports/."
fi
info "Testes OK."
