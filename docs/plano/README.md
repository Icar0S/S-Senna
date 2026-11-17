# Plano de Implementação — S-Senna

> Jogo de corrida arcade para PC, visual "PS2+", focado em **colecionar e customizar carros** e em **jogar a dois no mesmo PC**.
> Este plano foi escrito para ser executado por um agente de código (**Fable 5.2**), com revisão e playtest do dono do projeto.

---

## Documentos

| Documento | Para que serve |
|---|---|
| [00 — Visão do jogo](00-visao-do-jogo.md) | Pilares, referências, escopo, público, direção de arte |
| [01 — Ferramentas e tecnologias](01-ferramentas-e-tecnologias.md) | Stack escolhida, versões, justificativas, ADRs |
| [02 — Arquitetura](02-arquitetura.md) | Estrutura do repositório e do código, autoloads, fluxos, convenções |
| [03 — Formatos de dados](03-formatos-de-dados.md) | JSON de carros, peças, rodas, vinis, pistas, saves e configurações |
| [04 — Padrões de arte e pipeline de carros](04-padroes-de-arte-e-pipeline-de-carros.md) | Como modelar e preparar um carro; orçamentos; convenções do Blender |
| [05 — Riscos e questões legais](05-riscos-e-questoes-legais.md) | Riscos, licenças, marcas, decisões pendentes |
| [PROGRESSO](PROGRESSO.md) | Checklist de acompanhamento das etapas |

## Roteiro de etapas

| # | Etapa | Marco | Tamanho | Depende de |
|---|---|---|---|---|
| 00 | [Fundação do repositório e do projeto Godot](etapas/etapa-00-fundacao.md) | A | M | — |
| 01 | [Núcleo de conteúdo (dados, IDs, ContentDB)](etapas/etapa-01-nucleo-de-conteudo.md) | A | M | 00 |
| 02 | [Sistema de save](etapas/etapa-02-sistema-de-save.md) | A | M | 01 |
| 03 | [Montador de carros e shaders base](etapas/etapa-03-montador-de-carros.md) | A | G | 01, 02 |
| 04 | [Física arcade, câmera e campo de testes](etapas/etapa-04-fisica-e-campo-de-testes.md) | A | G | 03 |
| 05 | [Add-on do Blender (S-Senna CarKit)](etapas/etapa-05-addon-blender.md) | B | G | 01, 03 |
| 06 | [S-Senna Studio (a "engine" de criação)](etapas/etapa-06-senna-studio.md) | B | G | 01, 03, 04, 05 |
| 07 | [Dois controles e tela dividida](etapas/etapa-07-dois-controles-e-tela-dividida.md) | C | G | 04 |
| 08 | [Customização visual completa](etapas/etapa-08-customizacao-visual.md) | D | G | 03, 06 |
| 09 | [Garagem hub, Concessionária e economia](etapas/etapa-09-garagem-hub.md) | D | G | 02, 07, 08 |
| 10 | [Performance simplificada e tuning](etapas/etapa-10-performance-e-tuning.md) | D | M | 04, 09 |
| 11 | [Pistas e corridas (com IA)](etapas/etapa-11-pistas-e-corridas.md) | E | G | 07, 10 |
| 12 | [Visual "PS2+", efeitos e áudio](etapas/etapa-12-visual-e-audio.md) | E | G | 11 |
| 13 | [Carreira e história](etapas/etapa-13-carreira-e-historia.md) | F | M | 09, 11, 12 |
| 14 | [Releases e README final](etapas/etapa-14-release-e-readme.md) | F | M | todas |
| 15 | [Expansão contínua da concessionária e mods](etapas/etapa-15-expansao-continua.md) | contínuo | — | 05, 06 |

Tamanho: **P** pequena · **M** média · **G** grande (pode ser dividida em vários PRs).

### Dependências (visão geral)
```
00 → 01 → 02 → 03 → 04 ─────────────────► 07 ─────┐
                 │     └──► 06 ──► 08 ──► 09 ◄─────┘
                 └──► 05 ──┘              │
                                          ▼
                                         10 → 11 → 12 → 13 → 14

05 + 06 → 15 (contínuo, a partir do Marco B)
```
- **05 pode ser feita em paralelo com 04** (o add-on não depende da física).
- **07 pode ser feita em paralelo com 05/06** (só depende da 04).

## Marcos (o que dá para ver/jogar em cada um)

| Marco | Etapas | O que o dono consegue fazer |
|---|---|---|
| **A — Primeiro carro** | 00–04 | Ver o carro protótipo no showroom, trocar peças/rodas/pintura, salvar, e **dirigir** no campo de testes |
| **B — Concessionária funcionando** | 05–06 | **Colocar o primeiro carro da coleção no jogo** sozinho: Blender → Studio → test drive |
| **C — Dirigindo a dois** | 07 | Dois controles, tela dividida, cada um com seu carro |
| **D — Garagem completa** | 08–10 | Garagem estilo Midnight Club com toda a customização visual e performance |
| **E — Corridas** | 11–12 | Duas pistas, cinco modos, IA, visual e som finais |
| **F — Jogo 1.0** | 13–14 | Carreira, release pública e README final |

> A ordem prioriza o que o dono pediu: **montar a concessionária primeiro** (Marcos A e B), com a tela dividida logo em seguida (Marco C), porque ela afeta a arquitetura.

---

## Como o agente (Fable 5.2) deve executar cada etapa

1. **Ler antes de codar**: `CLAUDE.md` (raiz), docs `00`, `01`, `02`, `03` (e `04` quando a etapa envolver arte/carros) e o arquivo da etapa.
2. **Branches**: o trabalho acontece na branch **`dev`**; a **`main`** recebe o merge de `dev` quando a etapa é concluída.
   Não há branch por etapa (decisão do dono em 2026-11-16, na Etapa 00). Etapas G podem ser entregues em partes
   (`08a`, `08b`…), cada uma mesclada na `main` quando estiver verde.
3. **Implementar em commits pequenos**, sempre com testes junto do código.
4. Antes de mesclar na `main`, rodar localmente: `tools/ci/lint.sh`, `tools/ci/test.sh`, `tools/ci/validate_content.sh`, `tools/ci/check_architecture.sh` — e conferir o CI do push em `dev`.
5. Etapas visuais: gerar **capturas de tela** (`tools/scripts/screenshot.sh`) e mostrá-las ao dono na entrega.
6. **Entrega** com: resumo, checklist dos critérios de aceite no arquivo da etapa (🤖 marcados, 🎮 listados para o dono testar), riscos, o que ficou de fora.
7. Atualizar `PROGRESSO.md`, os guias em `docs/guias/` que a etapa pedir e o `CHANGELOG.md`.
8. Se algo do plano estiver errado ou impossível: **não improvisar em silêncio** — atualizar o documento do plano na mesma entrega, explicando o motivo (e uma ADR em `01` se for decisão técnica).
9. Itens 🧑 **decisão do dono**: usar o padrão indicado e registrar em `PROGRESSO.md` que a decisão está pendente.

> Onde os documentos das etapas falam em "PR" (por exemplo "CI verde em um PR"), leia como
> "merge de `dev` na `main`" — o CI roda a cada push em `dev` e em `main`.

## Legenda usada nos documentos
- 🤖 verificável automaticamente (testes/CI)
- 🎮 precisa de playtest humano (dono)
- 👀 conferência visual
- 🧑 decisão do dono
