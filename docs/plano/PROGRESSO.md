# Progresso

Atualizado pelo agente ao final de cada entrega (merge de `dev` na `main`). Marque `[x]` quando a etapa estiver
**mesclada** e com os critérios 🎮 aprovados pelo dono.

## Marco A — Primeiro carro
- [x] **00** Fundação do repositório e do projeto Godot
- [x] **01** Núcleo de conteúdo
- [ ] **02** Sistema de save — mesclada na `main`; falta o 🎮 do dono (fechar pelo X salva o perfil)
- [ ] **03** Montador de carros e shaders base — mesclada na `main`; falta o 🎮 do dono (a pintura no showroom)
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
| 2026-11-17 | 00 | — | 🎮 `jogar.bat` e `studio.bat` aprovados pelo dono. |
| 2026-11-17 | 03 | `dev` → `main` | Montador de carros: `CarAssembler`/`CarVisual`, peças por slot (inclusive universais em soquetes), 8 acabamentos de pintura, carbono, vidro e luzes (Forward+ e Compatibility), pneu procedural, rodas com aro/tala/offset/cambagem, altura, showroom com HDRI e painel de debug, capturas no CI. |
| 2026-11-17 | 02 | `dev` → `main` | Sistema de save: `SaveManager`/`ProfileStore` (escrita atômica, 3 backups, checksum, recuperação, lixeira, exportar/importar), `CarConfig` completo, `Settings` (aplica vídeo/áudio/idioma), `input.json`, migrações + golden v1, modo portátil, traduções pt_BR/en e tela de teste de perfis. Mods ligados agora vêm do `settings.json`. |
| 2026-11-17 | 01 | `dev` → `main` | Núcleo de conteúdo: `ContentDB`/`ContentLibrary`, definições tipadas, `ModelLoader`, `ConventionScanner`, JSON Schemas com `check-jsonschema`, gerador do carro de teste e primeiro conteúdo do pacote `base` (protótipo, 2 aros, 1 aerofólio, 12 pinturas, upgrades, economia). Etapa sem itens 🎮. |
