# Progresso

Atualizado pelo agente ao final de cada entrega (merge de `dev` na `main`). Marque `[x]` quando a etapa estiver
**mesclada** e com os critérios 🎮 aprovados pelo dono.

## Marco A — Primeiro carro
- [ ] **00** Fundação do repositório e do projeto Godot — mesclada na `main`; falta só o 🎮 do dono (rodar `jogar.bat` e `studio.bat`)
- [ ] **01** Núcleo de conteúdo
- [ ] **02** Sistema de save
- [ ] **03** Montador de carros e shaders base
- [ ] **04** Física arcade, câmera e campo de testes — 🎮 sensação de direção aprovada

## Marco B — Concessionária funcionando
- [ ] **05** Add-on do Blender
- [ ] **06** S-Senna Studio — 🎮 primeiro carro real da coleção no jogo

## Marco C — Dirigindo a dois
- [ ] **07** Dois controles e tela dividida — 🎮 testado com 2 controles reais

## Marco D — Garagem completa
- [ ] **08** Customização visual completa
- [ ] **09** Garagem hub, Concessionária e economia
- [ ] **10** Performance simplificada e tuning

## Marco E — Corridas
- [ ] **11** Pistas e corridas (com IA)
- [ ] **12** Visual "PS2+", efeitos e áudio

## Marco F — Jogo 1.0
- [ ] **13** Carreira e história
- [ ] **14** Releases e README final — 🎮 primeira release pública

## Contínuo
- [ ] **15** Gerador procedural de aros
- [ ] **15** Biblioteca universal nas metas da doc 04 §5
- Carros da coleção no jogo: **0** (ver `docs/colecao.md`)

## Decisões do dono
- [ ] D1 Nome final do jogo
- [ ] D2 Licença dos assets — em uso o padrão sugerido (**CC BY-NC-SA 4.0**, ver `LICENSE-ASSETS.md`) até o dono confirmar
- [ ] D3 Nomes reais vs. fictícios
- [ ] D4 Cenário da história
- [ ] D5 Ordem dos carros
- [ ] D6 Idiomas
- [ ] D7 itch.io

## Pendências do dono (fora do código)
- [ ] GitHub: trocar a branch padrão do repositório para `main` (Settings → General → Default branch) e apagar a branch de planejamento antiga.
- [ ] GitHub: criar labels e milestones com `tools/scripts/setup_github.sh` (precisa do GitHub CLI autenticado).

## Registro
| Data | Etapa | Entrega | Observações |
|---|---|---|---|
| 2026-11-15 | — | — | Plano criado |
| 2026-11-16 | 00 | `dev` → `main` | Fundação: projeto Godot 4.7.2, boot Jogo/Studio, `Log`, presets de exportação, gdUnit4 6.2.3, scripts e CI. Fluxo de branches mudou para `dev`/`main`. Desvios do plano anotados no arquivo da etapa. |
