#!/usr/bin/env bash
# Abre a tela de teste de perfis (saves).
exec "$(dirname "${BASH_SOURCE[0]}")/jogar.sh" res://game/sandbox/save_debug.tscn "$@"
