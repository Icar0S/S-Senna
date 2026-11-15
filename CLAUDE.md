# CLAUDE.md — instruções para o agente de código

## O projeto
S-Senna: jogo de corrida arcade para PC (Godot 4.7.x, GDScript tipado), visual "PS2+", foco em **customização visual de carros**
e **tela dividida com 2 controles**. Inclui um segundo programa, o **S-Senna Studio**, para adicionar carros/peças/rodas/vinis,
e um add-on do Blender. Repositório público.

## Antes de qualquer tarefa
1. Leia `docs/plano/README.md` (roteiro e regras de execução).
2. Leia `docs/plano/00` a `03`; e `04` se a tarefa envolver carros/arte.
3. Leia o arquivo da etapa em `docs/plano/etapas/` e confira `docs/plano/PROGRESSO.md`.

## Regras
- **Uma etapa por branch/PR** (`etapa-NN-nome`); etapas grandes podem ser divididas em PRs `NNa`, `NNb`…
- O projeto Godot fica em `godot/`. Código em **inglês**; docs e textos de UI em **pt-BR** (UI via chaves de tradução).
- GDScript **100% tipado**; lógica em classes `RefCounted` testáveis; nós finos.
- `godot/core/` **não** pode depender de `game/`, `studio/` nem de `GameSession`.
- Slots, materiais e soquetes vêm de `godot/core/content/conventions.json` — nada de strings mágicas.
- Conteúdo em JSON conforme `docs/plano/03-formatos-de-dados.md` + schema em `schemas/`. Mudou o formato? Atualize doc, schema e migração no mesmo PR.
- **Nunca** reutilize ou apague IDs de conteúdo publicados; use `aliases`.
- **Nunca** quebre saves: qualquer mudança de formato tem migração e teste com golden file.
- Nenhum asset de terceiros sem licença compatível registrada em `CREDITS.md`. Nada de modelos extraídos de outros jogos, logos reais ou músicas comerciais.
- Tudo que puder rodar no modo Compatibility deve rodar (shaders inclusos).
- Nada de `Input.is_action_pressed` genérico em código de jogador: sempre via `InputRouter` (multi-jogador).
- Se o plano estiver errado/inviável, atualize o documento do plano no PR explicando o motivo — não improvise em silêncio.

## Comandos
```bash
tools/ci/install_godot.sh           # instala a versão de .godot-version (CI/nuvem)
tools/ci/lint.sh                    # gdformat --check + gdlint
tools/ci/test.sh                    # testes gdUnit4 headless
tools/ci/validate_content.sh        # JSON Schemas do conteúdo
tools/ci/check_architecture.sh      # regras de dependência
tools/scripts/screenshot.sh <cena.tscn> <saida.png>   # captura para conferência visual
godot --path godot                  # rodar o jogo
godot --path godot -- --studio      # rodar o Studio
```
(Os scripts são criados na Etapa 00.)

## Antes de abrir o PR
- Lint, testes, validação e arquitetura verdes.
- Capturas de tela nas etapas visuais.
- Checklist dos critérios de aceite da etapa: 🤖 marcados; 🎮 listados para o dono testar.
- `PROGRESSO.md`, `CHANGELOG.md` e guias em `docs/guias/` atualizados quando a etapa pedir.
