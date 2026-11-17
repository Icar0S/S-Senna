#!/usr/bin/env bash
# Cria (ou atualiza) as labels e as milestones do projeto no GitHub.
# Requer o GitHub CLI autenticado: https://cli.github.com  (gh auth login)
# Idempotente: pode rodar de novo sem duplicar nada.
#
# Uso: tools/scripts/setup_github.sh
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../ci/_common.sh"

command -v gh > /dev/null 2>&1 || die "GitHub CLI (gh) não encontrado. Instale em https://cli.github.com e rode 'gh auth login'."
cd "$REPO_ROOT"

info "== Labels"
for number in 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15; do
  gh label create "etapa-$number" --color "1D76DB" --description "Etapa $number do plano" --force
done
gh label create "conteudo" --color "0E8A16" --description "Carros, peças, rodas, vinis, pistas" --force
gh label create "bug" --color "D73A4A" --description "Algo não funciona" --force
gh label create "ideia" --color "A2EEEF" --description "Sugestão de melhoria" --force
gh label create "playtest" --color "FBCA04" --description "Precisa de teste do dono (🎮)" --force

info "== Milestones"
existing="$(gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100" --jq '.[].title')"
create_milestone() {
  local title="$1" description="$2"
  if printf '%s\n' "$existing" | grep -Fxq "$title"; then
    info "já existe: $title"
  else
    gh api "repos/{owner}/{repo}/milestones" -f title="$title" -f description="$description" > /dev/null
    info "criada: $title"
  fi
}
create_milestone "Marco A — Primeiro carro" "Etapas 00–04: carro protótipo no showroom, customização básica, save e direção no campo de testes."
create_milestone "Marco B — Concessionária funcionando" "Etapas 05–06: primeiro carro da coleção no jogo (Blender → Studio → test drive)."
create_milestone "Marco C — Dirigindo a dois" "Etapa 07: dois controles e tela dividida."
create_milestone "Marco D — Garagem completa" "Etapas 08–10: customização visual completa, garagem hub e performance."
create_milestone "Marco E — Corridas" "Etapas 11–12: pistas, modos, IA, visual e áudio finais."
create_milestone "Marco F — Jogo 1.0" "Etapas 13–14: carreira, release pública e README final."

info "GitHub configurado."
