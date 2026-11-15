# 03 — Formatos de Dados

Todo conteúdo e todo save do S-Senna é **JSON**, com um JSON Schema correspondente em `schemas/`.
Este documento define os formatos. As etapas implementam exatamente o que está aqui; se mudar, atualize este
arquivo, o schema e a migração no mesmo PR.

---

## 1. Regras gerais

1. Todo arquivo tem os campos `"schema"` (tipo) e `"schema_version"` (inteiro, começa em 1).
2. Unidades SI internas (metros, kg, segundos). Exceções explícitas no nome do campo: `_kmh`, `_hp`, `_nm`, `_in` (polegadas), `_mm`, `_deg`, `_pct`.
3. Cores em hexadecimal `"#RRGGBB"` (sRGB).
4. Caminhos de arquivos são **relativos à pasta do próprio JSON**.
5. Campos desconhecidos geram **aviso** (não erro) — permite que versões novas leiam conteúdo antigo e vice-versa.
6. Nada de JSON com comentários nos arquivos reais (os comentários `//` abaixo são só explicação).

## 2. IDs de conteúdo

Formato: **`tipo:pacote/caminho`** — minúsculas, números, `_`, `-` e `/`.

| Tipo | Exemplo |
|---|---|
| Carro | `car:base/mazda_rx7_fd` |
| Peça específica de um carro | `part:base/mazda_rx7_fd/bumper_front-kit01` |
| Peça universal | `part:base/universal/spoiler/gt_wing_03` |
| Roda (aro) | `wheel:base/rally_6` |
| Vinil | `vinyl:base/tribal/chama_01` |
| Pintura (preset) | `paint:base/vermelho_corrida` |
| Perfil de som | `sound:base/engine/rotary_2r` |
| Pista | `track:base/campo_de_provas` |

- IDs **nunca** são reutilizados nem apagados de pacotes publicados (os saves dependem deles).
- Para renomear: manter o antigo em `aliases` no `pack.json` (`"antigo": "novo"`).
- O `pacote` evita colisão entre o conteúdo oficial e mods.

## 3. Estrutura de um pacote de conteúdo

```
content/packs/base/
├── pack.json
├── cars/<slug>/            car.json, model.glb, thumb.png, colecao.jpg (opcional), presets/*.json
├── parts/universal/<slot>/<slug>/   part.json, model.glb, thumb.png
├── wheels/<slug>/          wheel.json, rim.glb, thumb.png
├── vinyls/<categoria>/     vinyls.json + arquivos .svg/.png
├── paints/                 paints.json
├── sounds/engine/<slug>/   sound.json + loops .ogg
├── tracks/<slug>/          track.json (a cena fica em godot/game/tracks/<slug>/)
├── upgrades/upgrades.json
├── economy.json
├── handling_global.json     # constantes globais de "feeling" da física (Etapa 04, editáveis pelo painel F2)
└── career/                 chapters.json, events.json, rivals.json, messages.json
```
Mods ficam em `user://mods/<pacote>/` com a mesma estrutura.

### 3.1 `pack.json`
```json
{
  "schema": "pack",
  "schema_version": 1,
  "id": "base",
  "name": "S-Senna Base",
  "version": "0.1.0",
  "authors": ["Equipe S-Senna"],
  "license": "Ver LICENSE-ASSETS.md",
  "depends": [],
  "priority": 0,
  "aliases": {}
}
```
- `priority`: maior vence quando dois pacotes definem o mesmo ID (permite mods que substituem conteúdo).

---

## 4. Convenções compartilhadas — `conventions.json`

Arquivo em `godot/core/content/conventions.json`. **Fonte única** usada pelo Godot (constantes), pelo Studio,
pelo add-on do Blender e pelo CI.

```json
{
  "schema": "conventions",
  "schema_version": 1,
  "slots": {
    "replace": ["body", "bumper_front", "bumper_rear", "side_skirts", "hood", "spoiler", "mirrors",
                "headlights", "taillights", "fenders", "roof", "trunk", "exhaust", "grille"],
    "attach":  ["lip_front", "lip_rear", "canards", "hood_scoop", "roof_scoop", "wing_universal"]
  },
  "sockets": ["spoiler", "exhaust_L", "exhaust_R", "lip_front", "lip_rear", "canard_L", "canard_R",
              "hood_scoop", "roof_scoop", "plate_front", "plate_rear", "neon", "cam_hood", "cam_bumper",
              "light_head_L", "light_head_R", "light_tail_L", "light_tail_R"],
  "wheels": ["FL", "FR", "RL", "RR"],
  "materials": ["paint_body", "paint_secondary", "trim_black", "carbon", "chrome", "metal_dark",
                "glass", "glass_light", "light_head", "light_tail", "light_signal", "rubber",
                "interior", "rim", "rim_accent", "caliper", "plate"],
  "material_prefix_keep": "tex_",
  "name_separator": "-",
  "budgets": { "car_total_tris": 45000, "body_tris": 35000, "part_tris": 4000, "rim_tris": 4000 }
}
```

### 4.1 Slots (onde as peças encaixam)
| Slot | Tipo | Nome no jogo | Observação |
|---|---|---|---|
| `body` | replace | Carroceria | variantes widebody substituem a carroceria inteira |
| `bumper_front` / `bumper_rear` | replace | Para-choque dianteiro / traseiro | específicos do carro |
| `side_skirts` | replace | Saias laterais | |
| `hood` | replace | Capô | aceita acabamento carbono |
| `spoiler` | replace | Aerofólio | aceita peças do carro **ou** universais (no soquete `spoiler`) |
| `mirrors` | replace | Retrovisores | |
| `headlights` / `taillights` | replace | Faróis / Lanternas | |
| `fenders` | replace | Para-lamas / alargadores | |
| `roof` | replace | Teto | ex.: teto de carbono |
| `trunk` | replace | Tampa traseira | |
| `exhaust` | replace | Escapamento / ponteiras | universais nos soquetes `exhaust_L/R` |
| `grille` | replace | Grade | opcional |
| `lip_front`, `lip_rear` | attach | Lip dianteiro / difusor | universais, ajustados à largura do soquete |
| `canards` | attach | Canards | universais, par L/R |
| `hood_scoop`, `roof_scoop` | attach | Entrada de ar no capô / teto | universais |
| `wing_universal` | attach | (interno) | usado quando um aerofólio universal substitui o original |

### 4.2 Materiais (como o modelador "pede" um material)
O modelador só dá o **nome** certo ao material no Blender; o jogo troca pelo material real.

| Nome | O que vira no jogo | Customizável pelo jogador |
|---|---|---|
| `paint_body` | Shader de pintura principal (recebe vinis) | cor, acabamento, vinis |
| `paint_secondary` | Pintura secundária (dois tons) | cor, acabamento |
| `trim_black` | Plástico preto fosco | pode ser pintado na cor do carro |
| `carbon` | Fibra de carbono | — |
| `chrome` | Cromado | — |
| `metal_dark` | Metal escuro (grelhas, ponteiras) | — |
| `glass` | Vidro | cor/escurecimento (insulfilme) |
| `glass_light` | Lente de farol/lanterna | — |
| `light_head` | Refletor do farol (emissivo) | cor do xenon |
| `light_tail` | Lanterna (emissivo, intensifica ao frear) | — |
| `light_signal` | Pisca (âmbar) | — |
| `rubber` | Borracha | — |
| `interior` | Interior escuro simples | — |
| `rim` / `rim_accent` | Pintura do aro / da borda do aro | cor, acabamento |
| `caliper` | Pinça de freio | cor |
| `plate` | Placa (textura gerada com o texto) | texto |
| `tex_*` | **Mantém o material original com textura** (ex.: `tex_grade`, `tex_painel`) | — |

### 4.3 Nomes de objetos no modelo (.glb)
Separador **`-`** (hífen). Ponto (`.`) é proibido porque o Godot não aceita pontos em nomes de nós.

| Objeto | Nome | Exemplo |
|---|---|---|
| Carroceria principal | `body-<variante>` | `body-stock`, `body-wide01` |
| Peça | `<slot>-<variante>` | `bumper_front-stock`, `bumper_front-kit01`, `hood-kit02` |
| Soquete (Empty) | `socket-<nome>` | `socket-spoiler`, `socket-exhaust_L` |
| Âncora de roda (Empty) | `wheel-<pos>` | `wheel-FL`, `wheel-RR` |
| Aro original (opcional) | `rim-stock` | um só aro; o jogo replica nas 4 rodas |
| Colisão (opcional) | `collision-<n>` | `collision-1` (malha simples, convexa) |
| Vidros, interior | `glass-stock`, `interior-stock` | partes fixas podem ficar dentro de `body-stock` |

- O add-on do Blender também grava **propriedades personalizadas** (`ss_role`, `ss_slot`, `ss_variant`) que chegam ao Godot como *metadata* (glTF `extras`). O jogo usa a metadata quando existir e o nome como reserva.
- ⚠️ Não terminar nomes com os sufixos de importação do Godot (`-col`, `-colonly`, `-convcol`, `-convcolonly`, `-rigid`, `-vehicle`, `-wheel`, `-navmesh`, `-occ`, `-occonly`, `-noimp`, `-loop`, `-cycle`) — o Godot interpretaria como instrução de importação. O validador do add-on e do Studio bloqueia isso.

---

## 5. Definição de carro — `car.json`

```json
{
  "schema": "car",
  "schema_version": 1,
  "id": "car:base/mazda_rx7_fd",
  "display_name": "Mazda RX-7 (FD3S)",
  "manufacturer": "Mazda",
  "year": 1999,
  "country": "JP",
  "category": "jdm",                       // jdm | euro | muscle | super | classico | utilitario | outro
  "description_key": "CAR_RX7_FD_DESC",    // texto traduzível (opcional)

  "model": "model.glb",
  "thumbnail": "thumb.png",

  "dimensions_mm": { "length": 4295, "width": 1760, "height": 1230, "wheelbase": 2425 },

  "parts": [
    { "slot": "body",         "variant": "stock" },
    { "slot": "bumper_front", "variant": "stock" },
    { "slot": "bumper_front", "variant": "kit01", "name": "Aero Street", "price": 1500, "style_points": 2 },
    { "slot": "bumper_front", "variant": "kit02", "name": "Track Attack", "price": 2600, "style_points": 3, "unlock": "chapter:2" },
    { "slot": "hood",         "variant": "stock", "finishes": ["paint", "carbon"] },
    { "slot": "spoiler",      "variant": "stock", "accepts_universal": true }
  ],

  "sockets": {
    "spoiler":   { "width_m": 1.32 },
    "lip_front": { "width_m": 1.68 },
    "exhaust_L": {}, "exhaust_R": {},
    "neon":      { "length_m": 3.6, "width_m": 1.5 }
  },

  "wheels": {
    "anchors": {                            // posição do centro do cubo, espaço do carro, metros (Godot: +Z = frente, +X = esquerda)
      "FL": [ 0.73, 0.31,  1.22], "FR": [-0.73, 0.31,  1.22],
      "RL": [ 0.73, 0.31, -1.20], "RR": [-0.73, 0.31, -1.20]
    },
    "tire_outer_diameter_m": 0.632,         // mantido fixo ao trocar o aro (aro maior = pneu mais baixo)
    "stock": { "rim": "rim-stock", "rim_in": 16, "width_in": 8.0 },
    "rim_in_min": 15, "rim_in_max": 20,
    "width_in_min": 7.0, "width_in_max": 10.5,
    "max_offset_mm": 30, "max_camber_deg": 8
  },

  "paint": {
    "zones": ["paint_body", "paint_secondary"],
    "default": { "paint_body": { "finish": "metallic", "color": "#B3121B", "flake": 0.5 } }
  },

  "stats": {
    "power_hp": 280, "torque_nm": 314, "redline_rpm": 8000,
    "mass_kg": 1280, "weight_front_pct": 50,
    "drivetrain": "RWD",                    // FWD | RWD | AWD
    "gears": 5,
    "top_speed_kmh": 250,
    "grip": 0.72, "handling": 0.80, "braking": 0.70   // 0..1 (sensação; o HandlingModel converte)
  },

  "sound": "sound:base/engine/rotary_2r",

  "economy": { "price": 32000, "unlock": "default" },  // default | chapter:N | event:<id> | never (só sandbox)

  "camera": { "garage_distance_m": 5.2 },

  "collection": {
    "has_miniature": true,
    "miniature_brand": "Tomica",
    "scale": "1:64",
    "acquired": "2021-05",
    "photo": "colecao.jpg",
    "notes": "Primeira miniatura da coleção.",
    "livery_preset": "presets/miniatura.json"   // pintura igual à da miniatura (opcional)
  },

  "credits": { "model_author": "Nome do autor", "license": "CC-BY-NC-SA-4.0", "source": "modelado do zero" }
}
```

- `parts`, `sockets` e `wheels.anchors` são **escritos automaticamente** pelo Studio a partir do `.glb` (ninguém digita isso à mão). O validador confere se o JSON bate com o modelo.
- ID de cada peça específica = `part:<pacote>/<slug-do-carro>/<slot>-<variante>`.
- Peças sem `price` usam o preço padrão do slot × fator da categoria do carro (em `economy.json`).
- Campo opcional `tuning_overrides` (objeto): ajustes finos de física deste carro salvos pelo painel F2 / test drive do Studio (Etapa 04/06). Sobrescrevem os valores calculados pelo `HandlingModel`.

## 6. Peça universal — `part.json`
```json
{
  "schema": "part",
  "schema_version": 1,
  "id": "part:base/universal/spoiler/gt_wing_03",
  "slot": "spoiler",                        // ou lip_front, canards, hood_scoop, roof_scoop, exhaust...
  "display_name": "GT Wing 03",
  "brand": "Kaizen Aero",                   // marcas de peças FICTÍCIAS
  "model": "model.glb",
  "thumbnail": "thumb.png",
  "fit": {
    "socket": "spoiler",
    "reference_width_m": 1.40,              // largura em que foi modelada
    "scale_x_min": 0.85, "scale_x_max": 1.15
  },
  "compatible": { "cars": "*", "exclude": [] },
  "rules": { "hides": ["spoiler"], "requires": [], "conflicts": [] },
  "finishes": ["paint", "carbon", "black"],
  "price": 2200,
  "style_points": 3,
  "unlock": "default"
}
```
- `rules.hides`: slots do carro escondidos quando a peça está instalada.
- `requires` / `conflicts`: lista de IDs de peças ou slots (ex.: um capô com entrada de ar que conflita com `hood_scoop`).

## 7. Roda — `wheel.json`
```json
{
  "schema": "wheel",
  "schema_version": 1,
  "id": "wheel:base/rally_6",
  "display_name": "Rally 6",
  "brand": "Kaizen Wheels",
  "style": "esportiva",                     // esportiva | multi_raios | deep_dish | classica | aero | luxo | off_road
  "model": "rim.glb",                       // modelado em 18" x 8", face externa virada para +X (ver doc 04)
  "thumbnail": "thumb.png",
  "rim_in_min": 15, "rim_in_max": 22,
  "width_in_min": 7.0, "width_in_max": 11.0,
  "paint_zones": ["rim", "rim_accent"],
  "default_paint": { "rim": { "finish": "metallic", "color": "#C0C0C0" } },
  "price": 1800,
  "style_points": 2,
  "unlock": "default",
  "spinner": false
}
```

## 8. Vinis — `vinyls.json` (por categoria)
```json
{
  "schema": "vinyl_set",
  "schema_version": 1,
  "category": "tribal",
  "category_name_key": "VINYL_CAT_TRIBAL",
  "vinyls": [
    { "id": "vinyl:base/tribal/chama_01", "file": "chama_01.svg", "colors": 1, "price": 300, "style_points": 1 },
    { "id": "vinyl:base/tribal/garra_02", "file": "garra_02.png", "colors": 3, "price": 450, "style_points": 1 }
  ]
}
```
- `colors: 1` → a imagem é uma máscara (alfa) pintada com 1 cor.
- `colors: 2` ou `3` → PNG em que os canais R, G e B são máscaras das cores 1, 2 e 3.
- `colors: 0` → imagem colorida usada como está (adesivos de "patrocinadores" fictícios).

## 9. Pintura — `paints.json`
```json
{
  "schema": "paint_catalog",
  "schema_version": 1,
  "finishes": ["solid", "metallic", "pearl", "matte", "satin", "chrome", "candy", "chameleon"],
  "presets": [
    { "id": "paint:base/vermelho_corrida", "name_key": "PAINT_RACING_RED", "finish": "solid",    "color": "#C8102E" },
    { "id": "paint:base/azul_perolado",    "name_key": "PAINT_PEARL_BLUE", "finish": "pearl",    "color": "#1A3CFF", "color2": "#9B5CFF", "flake": 0.4 },
    { "id": "paint:base/camaleao_roxo",    "name_key": "PAINT_CHAMELEON",  "finish": "chameleon","color": "#5B1E8A", "color2": "#1E8A6E" }
  ]
}
```

### 9.1 `PaintSpec` (usado em configurações e saves)
```json
{ "finish": "pearl", "color": "#1A3CFF", "color2": "#9B5CFF", "flake": 0.4, "gloss": 0.95 }
```
| Campo | Faixa | Significado |
|---|---|---|
| `finish` | ver catálogo | tipo de acabamento |
| `color` | hex | cor base |
| `color2` | hex (opcional) | cor do perolado / segunda cor do camaleão / cor interna do candy |
| `flake` | 0..1 | intensidade do metálico (flocos) |
| `gloss` | 0..1 | brilho do verniz (0 = fosco) |

## 10. Perfil de som do motor — `sound.json`
```json
{
  "schema": "sound_profile",
  "schema_version": 1,
  "id": "sound:base/engine/rotary_2r",
  "loops": [
    { "file": "idle.ogg",     "rpm": 1000, "load": "any" },
    { "file": "low_on.ogg",   "rpm": 3000, "load": "on"  },
    { "file": "low_off.ogg",  "rpm": 3000, "load": "off" },
    { "file": "mid_on.ogg",   "rpm": 5500, "load": "on"  },
    { "file": "high_on.ogg",  "rpm": 8000, "load": "on"  }
  ],
  "extras": { "turbo": "turbo_spool.ogg", "blowoff": "bov.ogg", "backfire": "pop.ogg" }
}
```

## 11. Pista — `track.json`
```json
{
  "schema": "track",
  "schema_version": 1,
  "id": "track:base/centro",
  "display_name_key": "TRACK_DOWNTOWN",
  "scene": "res://game/tracks/centro/centro.tscn",
  "time_of_day": "noite",
  "weather": "molhado",
  "layouts": [
    { "id": "circuito",          "type": "circuit", "node": "Layouts/Circuito",          "default_laps": 3, "reversible": true },
    { "id": "sprint_porto",      "type": "sprint",  "node": "Layouts/SprintPorto" },
    { "id": "drag_avenida",      "type": "drag",    "node": "Layouts/DragAvenida" },
    { "id": "drift_estacionamento", "type": "drift", "node": "Layouts/DriftEstacionamento" }
  ]
}
```
Cada nó de layout na cena contém: `Checkpoints` (Area3D numerados), `RacingLine` (Path3D), `Grid` (Marker3D de largada) e, se `reversible`, a ordem invertida é calculada.

## 12. Upgrades de performance — `upgrades.json`
```json
{
  "schema": "upgrades",
  "schema_version": 1,
  "levels": ["stock", "rua", "pro", "elite"],
  "categories": {
    "engine":       { "effects_per_level": [{}, {"power_pct": 8},  {"power_pct": 18}, {"power_pct": 30}] },
    "turbo":        { "effects_per_level": [{}, {"power_pct": 6, "torque_pct": 8}, {"power_pct": 14, "torque_pct": 18}, {"power_pct": 24, "torque_pct": 30}] },
    "transmission": { "effects_per_level": [{}, {"shift_time_pct": -15}, {"shift_time_pct": -30}, {"shift_time_pct": -45}] },
    "suspension":   { "effects_per_level": [{}, {"handling_add": 0.04}, {"handling_add": 0.08}, {"handling_add": 0.12}] },
    "tires":        { "effects_per_level": [{}, {"grip_add": 0.04}, {"grip_add": 0.08}, {"grip_add": 0.13}] },
    "brakes":       { "effects_per_level": [{}, {"braking_add": 0.05}, {"braking_add": 0.10}, {"braking_add": 0.15}] },
    "nitrous":      { "effects_per_level": [{"nitro_capacity_s": 0}, {"nitro_capacity_s": 3}, {"nitro_capacity_s": 5}, {"nitro_capacity_s": 7}] },
    "weight":       { "effects_per_level": [{}, {"mass_pct": -3}, {"mass_pct": -6}, {"mass_pct": -10}] }
  },
  "price_factor_per_level": [0, 0.06, 0.14, 0.25]
}
```
Preço do upgrade = preço do carro × fator do nível (com mínimo definido em `economy.json`).

---

## 13. Configuração de um carro do jogador — `CarConfig`

É o que o save guarda para **cada carro da garagem do jogador**.
```json
{
  "instance_id": "c7f3a2",
  "car_id": "car:base/mazda_rx7_fd",
  "nickname": "RX-7 da Sexta",
  "parts": {
    "bumper_front": "part:base/mazda_rx7_fd/bumper_front-kit02",
    "spoiler":      "part:base/universal/spoiler/gt_wing_03",
    "lip_front":    "part:base/universal/lip_front/blade_01"
  },
  "part_finish": { "hood": "carbon", "spoiler": "carbon" },
  "part_fit":    { "spoiler": { "height_m": 0.04 } },
  "wheels": {
    "front": { "wheel_id": "wheel:base/rally_6", "rim_in": 18, "width_in": 9.0, "offset_mm": 15, "camber_deg": -3.0 },
    "rear":  { "wheel_id": "wheel:base/rally_6", "rim_in": 18, "width_in": 10.0, "offset_mm": 20, "camber_deg": -4.0 },
    "paint": { "rim": { "finish": "metallic", "color": "#202020" }, "rim_accent": { "finish": "chrome", "color": "#FFFFFF" } },
    "caliper_color": "#FFD000"
  },
  "stance": { "ride_height_mm": -35 },
  "paint": {
    "paint_body":      { "finish": "pearl", "color": "#F2F2F2", "color2": "#7FD3FF", "flake": 0.3, "gloss": 0.95 },
    "paint_secondary": { "finish": "matte", "color": "#111111" },
    "trim_black":      "body_color"
  },
  "vinyls": {
    "left":  [ { "vinyl_id": "vinyl:base/tribal/chama_01", "pos": [0.45, 0.55], "scale": [1.2, 0.6], "rot_deg": 12, "colors": ["#FF3B00"], "flip_h": false } ],
    "right": "mirror_left",
    "top": [], "front": [], "rear": []
  },
  "glass": { "tint": "#101418", "darkness": 0.6 },
  "lights": { "headlight_color": "#CFE6FF", "neon": { "enabled": true, "color": "#00E5FF", "mode": "fixo" } },
  "plate": { "text": "SNN-2026", "style": "generica_br" },
  "performance": { "engine": 2, "turbo": 3, "transmission": 1, "suspension": 2, "tires": 2, "brakes": 1, "nitrous": 3, "weight": 0 },
  "tuning": { "steering": 0.5, "grip_drift": 0.35, "brake_bias": 0.55, "gearing": 0.5, "downforce": 0.5, "nitro_style": "longo" },
  "stats": { "races": 14, "wins": 6, "distance_km": 182.4 }
}
```
- Coordenadas de vinil (`pos`, `scale`) são normalizadas (0..1) na tela daquele lado do carro.
- Se um ID não existir mais (mod desativado), o jogo **mantém o ID no save** e mostra a peça original — nunca apaga dados do jogador.

## 14. Save de perfil — `profile.json`
Local: `<pasta de saves>/profiles/<profile_id>/profile.json` (+ `.bak1`, `.bak2`, `.bak3`).
```json
{
  "schema": "profile",
  "schema_version": 1,
  "game_version": "0.4.0",
  "saved_at": "2026-11-15T21:03:00Z",
  "checksum": "sha256:…",                   // do conteúdo de "data"; detecta arquivo corrompido
  "data": {
    "profile": { "id": "p01", "name": "Jogador 1", "created_at": "2026-11-15T20:00:00Z", "sandbox": false, "avatar": 3 },
    "wallet": { "money": 12000, "reputation": 340 },
    "garage": { "selected": "c7f3a2", "cars": [ /* CarConfig... */ ] },
    "unlocks": { "parts": [], "cars": [], "vinyls": [], "wheels": [] },
    "career": { "chapter": 2, "events_done": { "evt_c1_01": { "best_pos": 1 } }, "messages_read": ["msg_001"] },
    "records": { "track:base/centro#circuito": { "best_lap_ms": 61234, "car_instance": "c7f3a2" } },
    "my_colors": ["#00E5FF", "#FF3B00"],
    "looks": [ { "name": "Estilo Neon", "car_id": "car:base/mazda_rx7_fd", "config": { /* parte visual do CarConfig */ } } ],
    "player_prefs": { "camera": "chase_far", "assists": { "steering": true, "stability": true, "abs": true, "traction": true, "gearbox": "auto" } },
    "stats": { "races": 40, "wins": 17, "distance_km": 610.2, "money_earned": 98000 }
  }
}
```
- `sandbox: true` = **Modo Colecionador**: tudo liberado e grátis (ideal para o dono só curtir os carros).
- Preferências de direção (assistências, câmera) ficam no **perfil**, porque cada jogador tem as suas.

## 15. Configurações — `settings.json` e `input.json`
```json
{
  "schema": "settings",
  "schema_version": 1,
  "video": { "window_mode": "fullscreen", "resolution": [1920, 1080], "vsync": true, "fps_limit": 0,
             "quality": "alto", "render_scale": 1.0, "upscaler": "fsr2", "split_layout": "horizontal", "fov": 75 },
  "audio": { "master": 0.9, "music": 0.6, "sfx": 0.8, "engine": 0.9, "ui": 0.7, "music_folder": "" },
  "gameplay": { "units": "kmh", "language": "pt_BR", "hud_scale": 1.0, "vibration": true },
  "mods": { "enabled": ["base"] }
}
```
```json
{
  "schema": "input",
  "schema_version": 1,
  "known_devices": { "030000005e040000ea02000000007801": { "last_player": 0, "name": "Xbox Wireless Controller" } },
  "bindings": {
    "p1": { "throttle": ["joy_axis:5+", "key:W"], "brake": ["joy_axis:4+", "key:S"] },
    "p2": { "throttle": ["joy_axis:5+", "key:UP"] }
  }
}
```
- `known_devices` usa o GUID do controle (`Input.get_joy_guid`) para lembrar quem é o Jogador 1 e o Jogador 2.

## 16. Versionamento e migrações
- Ao carregar, se `schema_version` < atual → aplicar migrações em sequência (`v1→v2`, `v2→v3`…) **antes** de converter para classes.
- Cada migração é um arquivo em `core/save/migrations/` com teste usando um arquivo antigo real ("golden file") em `tests/fixtures/saves/`.
- Se `schema_version` > atual (save de uma versão mais nova do jogo) → **não sobrescrever**: abrir em modo somente leitura e avisar.
