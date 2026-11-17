# 02 — Arquitetura

Como o repositório, o projeto Godot e o código são organizados. Todas as etapas seguem este documento;
se algo precisar mudar, atualize este arquivo no mesmo PR.

---

## 1. Estrutura do repositório

```
S-Senna/
├── README.md                    # pt-BR: o que é, como baixar, jogar e rodar do código
├── CLAUDE.md                    # instruções para o agente de código
├── CONTRIBUTING.md              # fluxo de PR, convenções
├── LICENSE                      # MIT (código)
├── LICENSE-ASSETS.md            # licença da arte/áudio (decisão do dono)
├── CREDITS.md                   # créditos de todo asset de terceiros
├── CHANGELOG.md                 # formato "Keep a Changelog"
├── .godot-version               # versão exata do Godot (ex.: 4.7.2)
├── .gitattributes               # regras do Git LFS e fim de linha
├── .gitignore
├── .editorconfig
├── .github/
│   ├── workflows/ci.yml         # lint, testes, validação de conteúdo, arquitetura
│   ├── workflows/release.yml    # exporta e publica builds ao criar tag v*
│   └── ISSUE_TEMPLATE/          # formulário "Novo carro", "Bug", "Ideia"
├── docs/
│   ├── plano/                   # este plano
│   ├── guias/                   # guias de uso criados durante as etapas
│   └── colecao.md               # lista das miniaturas → status no jogo
├── schemas/                     # JSON Schemas (car, part, wheel, pack, profile...)
├── godot/                       # ◄── O PROJETO GODOT (único)
│   ├── project.godot
│   ├── export_presets.cfg
│   ├── boot/                    # cena de entrada: decide Jogo ou Studio
│   ├── core/                    # código compartilhado por Jogo e Studio
│   │   ├── content/             # ContentDB, definições (CarDef...), loaders, validação, constantes
│   │   ├── save/                # SaveManager, migrações, Settings
│   │   ├── vehicle/             # física, montagem visual (CarAssembler), rodas, áudio do motor
│   │   ├── input/               # InputRouter, PlayerSlot, dispositivos
│   │   ├── render/              # shaders, biblioteca de materiais, presets de qualidade
│   │   ├── camera/              # câmeras de perseguição/garagem
│   │   ├── debug/               # telemetria, overlays, captura de tela
│   │   └── util/                # Log, helpers de arquivo/JSON/matemática
│   ├── game/                    # o JOGO: menus, garagem, corridas, carreira, HUD
│   │   ├── main_menu/
│   │   ├── garage/
│   │   ├── race/
│   │   ├── career/
│   │   ├── split_screen/
│   │   ├── hud/
│   │   ├── tracks/              # cenas das pistas (.tscn) e seus assets específicos
│   │   └── sandbox/             # cenas de teste (showroom, campo plano)
│   ├── studio/                  # o S-SENNA STUDIO (ferramenta de criação)
│   ├── ui/                      # tema, fontes, componentes de UI reutilizáveis, traduções
│   ├── content/
│   │   └── packs/
│   │       └── base/            # conteúdo oficial (carros, peças, rodas, vinis, sons, pistas...)
│   ├── addons/                  # plugins de terceiros (versões fixadas + licenças)
│   └── tests/                   # unit/, integration/, fixtures/
├── tools/
│   ├── blender/senna_carkit/    # add-on do Blender (Etapa 05)
│   ├── ci/                      # install_godot.sh, lint.sh, test.sh, export.sh, validate_content.sh
│   ├── fixtures/                # scripts que geram assets de teste (carro de teste etc.)
│   └── scripts/                 # jogar.sh/.bat, studio.sh/.bat, screenshot.sh
└── source_assets/               # .blend, .kra, .svg originais (Git LFS) — fora do projeto Godot
```

**Por que o projeto Godot fica em `godot/` e não na raiz?** Para o Godot não importar docs, ferramentas e arquivos-fonte
do Blender. Tudo que o jogo precisa fica dentro de `godot/`.

---

## 2. Dois programas, um projeto

```
                      ┌──────────────── boot/boot.tscn ────────────────┐
                      │  feature "studio" OU argumento "--studio" ?     │
                      └──────────┬───────────────────────┬─────────────┘
                                 │ não                   │ sim
                                 ▼                       ▼
                     game/main_menu (JOGO)      studio/studio_main (STUDIO)
                                 │                       │
            ┌────────────────────┴───────────────────────┴────────────────┐
            │                           core/                              │
            │  ContentDB · SaveManager · Settings · InputRouter · Log      │
            │  CarAssembler · Vehicle · MaterialLibrary · Shaders          │
            └────────────────────┬─────────────────────────────────────────┘
                                 ▼
          res://content/packs/*   +   user://mods/*   +   --content-dir=<pasta>
```

- **Mesmo código de montagem e renderização** no Jogo e no Studio: o carro que você vê no Studio é idêntico ao do jogo.
- O Studio pode abrir um **test drive** usando a mesma cena de física do jogo.
- `boot.gd` nunca referencia a cena do Studio de forma fixa (carrega pelo caminho em texto só quando necessário), para que a pasta `studio/` possa ser **excluída** da exportação do jogo.
- Como rodar do código-fonte:
  - Jogo: `godot --path godot`
  - Studio: `godot --path godot -- --studio`
  - Scripts prontos: `tools/scripts/jogar.sh|.bat` e `tools/scripts/studio.sh|.bat`.

### Presets de exportação
| Preset | Plataforma | Feature customizada | Inclui | Exclui |
|---|---|---|---|---|
| Jogo - Windows | Windows x86_64 | — | `*.json` (filtro de inclusão) | `studio/*`, `tests/*`, `reports/*`, `addons/gdUnit4/*` |
| Jogo - Linux | Linux x86_64 | — | `*.json` | idem |
| Studio - Windows | Windows x86_64 | `studio` | `*.json` | `tests/*`, `reports/*`, `addons/gdUnit4/*` |
| Studio - Linux | Linux x86_64 | `studio` | `*.json` | idem |

> ⚠️ **Armadilha**: arquivos que não são "recursos" do Godot (como `.json`) **não entram na exportação** sem o filtro de inclusão `*.json`. Testar isso na Etapa 00.
>
> `tools/ci/export.sh` exporta e confere isso: roda cada build com `-- --self-check` e a cena de boot responde com uma
> linha `SELF_CHECK {...}` dizendo se o JSON de conteúdo está na build e se `studio/` e `tests/` ficaram de fora.
> (`reports/` é a pasta de relatórios do gdUnit4, fora do Git.)

---

## 3. Autoloads (singletons)

Manter a lista **curta**. Cada autoload tem uma responsabilidade única.

| Autoload | Arquivo | Responsabilidade | Usado por |
|---|---|---|---|
| `Log` | `core/util/log.gd` | Log em console + arquivo (`user://logs`) com níveis | todos |
| `ContentDB` | `core/content/content_db.gd` | Descobre pacotes, carrega e indexa definições, resolve IDs e aliases | Jogo, Studio |
| `SaveManager` | `core/save/save_manager.gd` | Perfis, backups, migrações, autosave, modo portátil | Jogo, Studio (só settings) |
| `Settings` | `core/save/settings.gd` | Configurações em memória; aplica vídeo/áudio/idioma | Jogo, Studio |
| `InputRouter` | `core/input/input_router.gd` | Dispositivos → jogadores; ações por jogador | Jogo, Studio (test drive) |
| `SceneRouter` | `core/util/scene_router.gd` | Troca de cenas com tela de carregamento (carregamento em thread) | Jogo, Studio |
| `AudioDirector` | `core/audio/audio_director.gd` | Buses, rádio/música, sons de UI | Jogo |
| `GameSession` | `game/game_session.gd` | Estado da sessão atual: jogadores ativos, perfis, evento escolhido | só Jogo (não é autoload no Studio) |

`GameSession` é registrado como autoload, mas o código em `core/` **nunca** o referencia (regra de dependência abaixo).

---

## 4. Regras de dependência (verificadas no CI)

```
core/   ──►  (nada além de core/ e addons/)
game/   ──►  core/, ui/, content/
studio/ ──►  core/, ui/, content/   (e pode instanciar cenas de game/sandbox para test drive)
tests/  ──►  qualquer coisa
```
- Script `tools/ci/check_architecture.sh`: falha se algum arquivo em `godot/core/` contiver `res://game/` ou `res://studio/` ou usar `GameSession`;
  se `godot/game/` contiver `res://studio/`; ou se `godot/studio/` referenciar `res://game/` fora de `res://game/sandbox/`.

---

## 5. Módulos principais e classes-chave

### 5.1 Conteúdo (`core/content/`)
- `ContentId` — valida e decompõe IDs `tipo:pacote/caminho` (ver `03-formatos-de-dados.md`).
- `PackDef`, `CarDef`, `PartDef`, `WheelDef`, `VinylDef`, `PaintCatalog`, `TrackDef`, `SoundProfileDef`, `UpgradeTable` — `RefCounted` tipados com `static func from_dict(data: Dictionary, ctx: LoadContext) -> X`.
- `LoadContext` — caminho base do pacote, versão do schema e lista de erros/avisos (`ContentReport`).
- `ContentDB` — índice e consultas (`get_car`, `list_cars`, `list_parts_for(car_id, slot)`, `list_wheels`…).
- `ModelLoader` — carrega modelos: `res://` → `load()` (recurso importado); caminho externo → `GLTFDocument` (com cache).
- `ConventionScanner` — percorre a cena do modelo e classifica nós (carroceria, peças, soquetes, rodas, materiais) por *metadata* e por nome. **Compartilhado entre o jogo e o Studio.**
- `conventions.json` — **fonte única** de slots, nomes de materiais, soquetes e orçamentos de polígonos. Lido pelo Godot e copiado para o add-on do Blender.

### 5.2 Save (`core/save/`)
- `SaveManager`, `ProfileData`, `CarConfig` (customização de um carro do jogador), `SettingsData`, `Migrations`.

### 5.3 Veículo (`core/vehicle/`)
```
Vehicle (RigidBody3D)
├── CarVisual (Node3D)             ← criado pelo CarAssembler a partir de CarDef + CarConfig
├── WheelSuspension ×4 (RayCast3D) ← suspensão, tração, aderência
├── CollisionShape3D ×N            ← caixas geradas das dimensões (ou malhas collision-*)
├── VehicleAudio                   ← loops de motor, pneus, turbo
└── VehicleFX                      ← fumaça, faíscas, rastros de luz, nitro
```
- `CarAssembler` — monta o visual (peças, rodas, materiais, vinis). Não sabe nada de física.
- `HandlingModel` — função pura: (stats base + upgrades + ajustes + assistências) → `VehicleParams`. **Toda a "sensação" do carro passa por aqui** e é testada.
- `Drivetrain` — curva de torque simplificada, câmbio automático/manual, RPM.
- `VehicleInput` — struct com `throttle`, `brake`, `steer`, `handbrake`, `nitro`, `shift_up/down`. Preenchida por `PlayerDriver` (controle/teclado) **ou** `AIDriver`. O veículo não sabe quem está dirigindo.

### 5.4 Entrada (`core/input/`)
- `InputRouter` — mantém a lista de dispositivos (teclado, joypads) e qual jogador usa cada um.
- `PlayerSlot` — índice do jogador (0 ou 1), dispositivo, perfil, câmera, HUD, veículo.
- Ações por jogador: `p1_throttle`, `p2_throttle`… geradas em tempo de execução a partir de `InputActions` (lista base), filtrando o `device` de cada evento.
- ⚠️ Teclado e o primeiro joypad podem ter `device == 0`. Sempre identificar o dispositivo pelo par **(tipo do evento, device)**: `kbd` vs `joy:0`.

### 5.5 Jogo (`game/`)
- `SplitScreenLayout` — 1 ou 2 `PlayerView` (SubViewportContainer + SubViewport + câmera + HUD), horizontal ou vertical.
- `GarageController`, `ShopCatalog`, `Economy`.
- `RaceManager`, `RaceParticipant`, `Checkpoint`, `RacingLine`, `AIDriver`.
- `CareerManager`.

### 5.6 Studio (`studio/`)
- `StudioMain`, `PackBrowser`, `ImportWizard`, `Inspector` (formulários gerados a partir de especificações de campos), `ThumbnailRenderer`, `ValidatorPanel`, `ContentWriter`, `TestDriveLauncher`.

---

## 6. Fluxos principais

### 6.1 Inicialização
```
boot → Log → Settings (lê settings.json) → ContentDB.scan() → SaveManager (lista perfis)
     → Jogo: tela de título → seleção de perfil → garagem
     → Studio: navegador de pacotes
```

### 6.2 Montagem de um carro
```
CarConfig (do save) + CarDef (do ContentDB)
   → CarAssembler.build()
       1. ModelLoader carrega o modelo (cache por caminho)
       2. ConventionScanner classifica nós
       3. MaterialLibrary troca materiais por nome (paint_body → shader de pintura da instância)
       4. Slots: mostra a peça escolhida, esconde a original; peças universais vão para os soquetes
       5. Rodas: aro + pneu (gerado) em cada âncora; tamanho, tala, offset, cambagem
       6. Vinis: VinylCompositor gera as texturas por lado e aplica no shader
   → CarVisual pronto (mesmo código no Jogo e no Studio)
```

### 6.3 Entrada → carro
```
InputEvent (device X) → InputRouter → PlayerSlot N → ações pN_* → PlayerDriver → VehicleInput → Vehicle
                                                                  AIDriver ──────┘
```

### 6.4 Save
```
mudança relevante (compra, sair da garagem, fim de corrida)
   → SaveManager.request_save(perfil, motivo)   (agrupa pedidos por ~1 s)
   → serializa → grava .tmp → gira backups (.bak1..3) → renomeia .tmp → atualiza ícone "salvo"
```

---

## 7. Convenções de código

| Item | Convenção |
|---|---|
| Idioma do código | **Inglês** (nomes de classes, variáveis, arquivos) |
| Idioma dos textos | Chaves de tradução (`tr("GARAGE_TITLE")`) em `godot/ui/i18n/strings.csv` — **pt_BR** (padrão) e **en** |
| Idioma dos docs | **Português (Brasil)** |
| Arquivos | `snake_case.gd`, `snake_case.tscn` |
| Classes | `class_name PascalCase` |
| Nós na cena | `PascalCase` |
| Sinais | verbo no passado: `car_purchased`, `lap_completed` |
| Constantes | `UPPER_SNAKE_CASE` |
| Tipagem | 100% estática (aviso `untyped_declaration` = erro) |
| Strings mágicas | Proibidas para slots/materiais/ações: usar constantes de `core/content/constants.gd` (geradas de `conventions.json`) |
| Unidades internas | SI: metros, kg, segundos, newtons, radianos. Conversão (km/h, cv, polegadas) **só na UI** |
| Lógica vs nós | Lógica em classes `RefCounted` testáveis; nós finos que só conectam lógica e cena |
| Erros de conteúdo | Nunca derrubam o jogo: vão para o `ContentReport`; o jogo usa a peça original/padrão como substituta |
| Hot paths | Nada de alocação, `get_node` com caminho em texto ou concatenação de strings dentro de `_physics_process` |
| Comentários | Explicar o **porquê**; docstrings `##` em classes e funções públicas |

### Padrões de cena
- Cada cena reutilizável tem um script na raiz com `class_name`.
- Comunicação: de pai para filho por chamada de método; de filho para pai por sinal.
- Sem `get_tree().get_root().get_node(...)` para achar coisas — usar referências exportadas ou grupos.

---

## 8. Configurações importantes do `project.godot`
| Configuração | Valor | Motivo |
|---|---|---|
| `application/config/name` | `S-Senna` | — |
| `application/config/version` | `0.0.1` (SemVer) | Mostrado na tela de título e nos saves |
| `application/config/use_custom_user_dir` | `true` | Saves em `%APPDATA%\S-Senna` / `~/.local/share/S-Senna` |
| `application/config/custom_user_dir_name` | `S-Senna` | — |
| `rendering/renderer/rendering_method` | `forward_plus` | ADR 001 / seção 2.4 do doc 01 |
| `physics/3d/physics_engine` | `Jolt Physics` | — |
| `physics/common/physics_ticks_per_second` | `120` | Estabilidade dos carros |
| `physics/common/physics_interpolation` | `true` | Movimento suave |
| `display/window/stretch/mode` | `canvas_items`, aspecto `expand` | UI escala em qualquer resolução |
| `debug/gdscript/warnings/untyped_declaration` | Erro | Tipagem obrigatória |
| `internationalization/locale/fallback` | `pt_BR` | — |

---

## 9. Testes
| Tipo | Onde | Exemplo |
|---|---|---|
| Unitário | `godot/tests/unit/` | `HandlingModel`, `CarConfig`, `ContentId`, migrações de save, regras de peças |
| Integração (cena, headless) | `godot/tests/integration/` | carro acelera de 0 a 100 dentro da faixa; IA completa uma volta; montagem de carro sem avisos |
| Fixtures | `godot/tests/fixtures/` | pacote de teste com carro gerado por script (fora do LFS) |
| Visual (para o agente) | `tools/scripts/screenshot.sh` | captura de showroom, garagem, tela dividida |
| Manual (dono) | checklist no PR | sensação de direção, beleza, diversão |

Comando único: `tools/ci/test.sh` (roda gdUnit4 headless). O CI roda: `lint.sh`, `test.sh`, `validate_content.sh`, `check_architecture.sh`,
`export.sh linux` (exporta Jogo e Studio e confere o conteúdo das builds) e `screenshot.sh` (telas de título, via Xvfb).
