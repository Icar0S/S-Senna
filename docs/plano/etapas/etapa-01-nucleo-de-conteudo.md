# Etapa 01 — Núcleo de conteúdo (dados, IDs, ContentDB, validação)

> **Marco:** A · **Depende de:** 00 · **Tamanho:** M
> **Resultado:** o jogo descobre pacotes, lê carros/peças/rodas em JSON com validação e carrega modelos `.glb` (do projeto ou de fora).

## Objetivo
Criar a camada que transforma arquivos de conteúdo em objetos tipados e confiáveis. Tudo o que vem depois
(Studio, garagem, concessionária, mods) depende disso.

## Entregáveis
- `godot/core/content/conventions.json` (conteúdo de `03-formatos-de-dados.md` §4) e `constants.gd` gerado/lido a partir dele.
- Classes de definição: `ContentId`, `PackDef`, `CarDef`, `PartDef`, `WheelDef`, `VinylDef`, `PaintCatalog`, `PaintSpec`, `TrackDef`, `SoundProfileDef`, `UpgradeTable`, `EconomyDef`.
- `LoadContext` + `ContentReport` (erros e avisos com arquivo, campo e mensagem em português).
- Autoload `ContentDB`.
- `ModelLoader` (importado vs. externo) e `ConventionScanner`.
- JSON Schemas em `schemas/` para todos os tipos acima; `validate_content.sh` passa a usar `check-jsonschema`.
- Pacote de **fixtures** gerado por script e o primeiro conteúdo do pacote `base` (carro protótipo).

## Tarefas
1. **`ContentId`**: `parse("car:base/mazda_rx7_fd")` → tipo, pacote, caminho; validação por regex; erros claros.
2. **Definições tipadas**: cada uma com `static func from_dict(d: Dictionary, ctx: LoadContext)`; campos obrigatórios geram erro, desconhecidos geram aviso; valores fora da faixa são limitados com aviso.
3. **`ContentDB.scan()`**:
   - Fontes, em ordem: `res://content/packs/*`, `user://mods/*` (só os habilitados em `settings.mods.enabled`), pasta extra via argumento `--content-dir=<caminho>`.
   - Listagem de pastas que funcione em build exportada (usar `ResourceLoader.list_directory` / `DirAccess` e testar na build).
   - Ordenar por dependências e `priority`; aplicar `aliases`.
   - Índices por tipo; consultas: `get_car`, `list_cars(filtro)`, `get_part`, `list_parts_for(car_id, slot)` (específicas + universais compatíveis), `list_wheels(filtro)`, `list_vinyls(categoria)`, `get_track`, `get_sound`.
   - Peças específicas do carro são registradas a partir de `car.json.parts` (sem abrir o `.glb` no boot — rápido).
   - Sinal `content_reloaded` e função `rescan()` (usada pelo Studio).
4. **`ModelLoader.load_model(path) -> Node3D`**:
   - `res://...` → `load()` (cena importada pelo editor, com LODs e compressão).
   - caminho externo (`user://`, `--content-dir`) → `GLTFDocument.append_from_file` + `generate_scene`; texturas externas via `Image.load_from_file`.
   - Cache por caminho (guardar `PackedScene` e instanciar cópias).
5. **`ConventionScanner.scan(root: Node3D) -> ScanResult`**: classifica nós em carroceria, peças (slot/variante), soquetes, âncoras de roda, aro original, colisões; lista materiais usados; conta triângulos por objeto; usa metadata (`extras`) e, na falta, o nome.
6. **Teste de `extras`**: gerar um `.glb` com `extras` e confirmar que chega como metadata na versão fixada do Godot. Se não chegar, documentar e usar só nomes.
7. **Gerador de fixtures** `tools/fixtures/make_test_car.gd` (roda com `godot --headless -s`): cria com `SurfaceTool` um carro simples ("cunha" low-poly) seguindo **todas** as convenções (corpo, 2 variantes de para-choque, capô, aerofólio, soquetes, 4 âncoras, materiais nomeados) e exporta com `GLTFDocument.write_to_filesystem`. Saída em `godot/tests/fixtures/packs/fixture/` (fora do LFS) e uma versão "bonitinha" como `car:base/prototipo` no pacote base.
8. **Conteúdo inicial do pacote `base`**: `pack.json`, `car:base/prototipo`, 2 aros simples gerados por script, 1 aerofólio universal, `paints.json` com 12 presets, `upgrades.json` e `economy.json` iniciais.
9. **Schemas**: um arquivo por tipo em `schemas/`; `validate_content.sh` valida todo `godot/content/**/*.json` e as fixtures.
10. **Relatório**: `ContentReport.to_text()` para log e, futuramente, para o Studio.

## Critérios de aceite
### 🤖 Automáticos
- [x] Testes de `from_dict` para cada tipo: válido, campo faltando, tipo errado, valor fora da faixa, campo desconhecido (`tests/unit/content/test_definitions.gd`).
- [x] Pacote com `priority` maior substitui definição de mesmo ID; alias resolve ID antigo (`test_content_library.gd`).
- [x] `list_parts_for` retorna específicas + universais compatíveis e respeita `exclude` (inclusive `exclude` escrito com ID antigo/alias).
- [x] `ModelLoader` carrega o `.glb` da fixture por caminho externo (copiado para `user://`, como um mod; e por caminho absoluto) e por `res://` (`test_models.gd`).
- [x] `ConventionScanner` encontra exatamente as peças/soquetes/rodas da fixture e bate com o `car.json` (fixture e protótipo).
- [x] Varredura de 200 carros falsos em < 300 ms (`tests/integration/test_content_performance.gd`; medido: ~150 ms no Windows, ~80 ms no Linux).
- [x] Build exportada lista e carrega o pacote base (self-check: `content_errors: 0` e `probe_car_model: true`, conferido em Windows e Linux).
- [ ] CI valida JSON Schemas (job `content` com `check-jsonschema`) — conferir no push em `dev`.

## Armadilhas
- Em builds exportadas, os arquivos importados aparecem como `.import`/`.remap` na listagem de pastas — por isso o índice é baseado nos `.json`.
- Não carregar `.glb` durante o `scan()` (lento); só sob demanda.

## Fora do escopo
Montagem visual do carro (Etapa 03), Studio (Etapa 06).

## Notas de implementação (2026-11-17)
| Item | Como ficou | Motivo |
|---|---|---|
| Teste de `extras` (tarefa 6) | **Funciona** no Godot 4.7.2: metadata `extras` chega na importação pelo editor e no `GLTFDocument`; o exportador do Godot também grava | Usamos metadata com o nome como reserva, como previsto |
| `conventions.json` | Ganhou `node_prefixes`, `fixed_prefixes`, `metadata_keys`, `metadata_roles`, `forbidden_name_suffixes`, `part_finishes`, `paint_finishes` | Nada de strings mágicas no `ConventionScanner`; o add-on (Etapa 05) lê o mesmo arquivo. Doc 03 §4 atualizado |
| `constants.gd` | Classe `Conventions` que **lê** o `conventions.json` (com cache), em vez de gerar constantes | Uma fonte só, sem passo de geração; um teste confere que os papéis do scanner batem com o arquivo |
| Substituir IDs de outro pacote | Permitido só para pacotes em `depends` | Sem isso um erro de digitação no pacote do ID passaria despercebido; com isso o mod de prioridade maior funciona. Doc 03 §3.1 |
| `--content-dir` | Aceita um pacote, uma pasta de pacotes ou `content/` com `packs/`; pacote com o mesmo ID de um oficial o substitui | Etapa 06 usa `--content-dir=<repo>/godot/content` para editar o próprio pacote base |
| Mods habilitados | `ContentScanOptions.enabled_mods` (vazio por enquanto) | `settings.mods.enabled` nasce na Etapa 02 |
| `economy.json` | Formato definido (doc 03 §12.1) | O plano citava o arquivo, mas não o formato |
| Gerador de fixtures | `tools/fixtures/make_test_car.gd` (+ `.sh`) gera carro de teste, protótipo do `base`, 2 aros e 1 aerofólio; também escreve os `car.json` | `parts`/`sockets`/`anchors` saem dos mesmos números da geometria (o teste confere modelo × JSON) |
| Modelos gerados fora do LFS | Exceções no `.gitattributes` para os `.glb` gerados do pacote base | O CI faz checkout sem LFS e precisa deles para testes e exportação |
| Miniaturas (`thumb.png`) | Ainda não existem | São renderizadas pelo Studio (Etapa 06); campo opcional |
| Arcos de roda do protótipo | O corpo tem arcos simples (trapézio) | Suficiente para o showroom da Etapa 03; o gerador é fácil de refinar |

Achados úteis para as próximas etapas:
- **Packed arrays são passados por referência no Godot 4** (`PackedStringArray` guardado em `Dictionary`/variável estática): devolva `.duplicate()` quando o chamador puder modificar. Um teste pegou isso no cache do `Conventions`.
- O gdUnit4 6.2.3 interrompe o restante de uma suíte depois do primeiro teste que falha — a contagem de testes cai; não é sinal de teste apagado.
- `Resource.set_path` existe no próprio script: funções estáticas de helpers não podem se chamar `set_path`.
