#!/usr/bin/env bash
# Abre o showroom (pintura, peças e rodas).
exec "$(dirname "${BASH_SOURCE[0]}")/jogar.sh" res://game/sandbox/showroom_sandbox.tscn "$@"
