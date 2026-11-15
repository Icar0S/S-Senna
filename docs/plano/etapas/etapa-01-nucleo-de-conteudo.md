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
- [ ] Testes de `from_dict` para cada tipo: válido, campo faltando, tipo errado, valor fora da faixa, campo desconhecido.
- [ ] Pacote com `priority` maior substitui definição de mesmo ID; alias resolve ID antigo.
- [ ] `list_parts_for` retorna específicas + universais compatíveis e respeita `exclude`.
- [ ] `ModelLoader` carrega o `.glb` da fixture por caminho externo (como faria um mod) e por `res://`.
- [ ] `ConventionScanner` encontra exatamente as peças/soquetes/rodas da fixture.
- [ ] Varredura de 200 carros falsos em < 300 ms (teste de desempenho com margem).
- [ ] Build exportada lista e carrega o pacote base.
- [ ] CI valida JSON Schemas.

## Armadilhas
- Em builds exportadas, os arquivos importados aparecem como `.import`/`.remap` na listagem de pastas — por isso o índice é baseado nos `.json`.
- Não carregar `.glb` durante o `scan()` (lento); só sob demanda.

## Fora do escopo
Montagem visual do carro (Etapa 03), Studio (Etapa 06).
