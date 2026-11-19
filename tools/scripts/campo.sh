#!/usr/bin/env bash
# Abre o Campo Plano (dirigir; F1 telemetria, F2 ajustes).
exec "$(dirname "${BASH_SOURCE[0]}")/jogar.sh" res://game/sandbox/campo_plano/campo_plano.tscn "$@"
