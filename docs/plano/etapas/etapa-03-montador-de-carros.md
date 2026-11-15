# Etapa 03 — Montador de carros (CarAssembler) e shaders base

> **Marco:** A · **Depende de:** 01, 02 · **Tamanho:** G
> **Resultado:** um carro aparece num showroom, com peças trocáveis, rodas de vários tamanhos e pintura com acabamentos — e a escolha fica salva.

## Objetivo
Construir **o coração visual do jogo**: o código que pega uma definição de carro (`CarDef`) e a configuração do jogador
(`CarConfig`) e monta o carro na tela. O mesmo código será usado no jogo, na garagem, nas corridas e no Studio.

## Entregáveis
- `core/vehicle/car_assembler.gd`, `core/vehicle/car_visual.gd`.
- `core/render/material_library.gd` + shaders: `car_paint.gdshader`, `carbon.gdshader`, `glass.gdshader`, `car_light.gdshader`.
- `core/vehicle/tire_mesh_builder.gd` (pneu procedural).
- Cena de teste `game/sandbox/showroom_sandbox.tscn` com painel de debug.
- HDRI CC0 (Poly Haven) para o showroom, registrado em `CREDITS.md`.

## API do `CarVisual`
```gdscript
class_name CarVisual extends Node3D
signal rebuilt
func apply_config(config: CarConfig) -> void          # aplica tudo de uma vez
func set_part(slot: StringName, part_id: StringName) -> void
func set_part_finish(slot: StringName, finish: StringName) -> void
func set_paint(zone: StringName, paint: PaintSpec) -> void
func set_wheels(front: WheelSetup, rear: WheelSetup) -> void
func set_ride_height(mm: float) -> void
func set_lights(headlights: bool, brake: float, reverse: bool) -> void
func get_wheel_anchors() -> Dictionary                # "FL" -> Transform3D (usado pela física)
func get_socket(name: StringName) -> Node3D
func get_aabb_car_space() -> AABB
```

## Tarefas
1. **Carregar e classificar**: `ModelLoader` + `ConventionScanner` (Etapa 01). Guardar referências por slot/variante.
2. **Biblioteca de materiais** (`MaterialLibrary`):
   - Troca materiais por **nome** (`03-formatos-de-dados.md` §4.2).
   - Materiais compartilhados entre todos os carros (cromo, borracha, vidro de farol, interior…) — **uma instância só**.
   - Pintura: **uma instância de `ShaderMaterial` por carro por zona** (`paint_body`, `paint_secondary`, `rim`, `rim_accent`, `caliper`).
   - Materiais `tex_*` mantidos como vieram do modelo.
3. **Shader de pintura** `car_paint.gdshader` — acabamentos `solid`, `metallic`, `pearl`, `matte`, `satin`, `chrome`, `candy`, `chameleon`:
   - Base PBR com **clearcoat** (verniz) controlado por `gloss`.
   - Flocos metálicos: textura de ruído pequena, mapeada **triplanar no espaço do objeto** (não depende de UV).
   - Perolado e camaleão: mistura `color` → `color2` pelo ângulo de visão (fresnel).
   - Candy: cor profunda com `color2` como "fundo" brilhante.
   - Uniforms preparados para os vinis (Etapa 08): `vinyl_tex_left/right/top/front/rear` e `vinyl_enabled` (desligado por enquanto).
   - **Tem que compilar e ficar bom no Forward+ e no Compatibility.**
4. **Carbono** (trama procedural triplanar), **vidro** (transparente, cor + escurecimento), **luzes** (emissivo com intensidade de freio e ré).
5. **Slots**: para cada slot, mostrar a variante escolhida e esconder as demais; aplicar `rules.hides`; peças universais instanciadas no soquete com escala X ajustada à `width_m` (limitada a `scale_x_min..max`).
6. **Rodas**:
   - `TireMeshBuilder.build(outer_diameter_m, rim_in, width_in) -> ArrayMesh` com cache por parâmetros (perfil calculado para manter o diâmetro externo fixo).
   - Aro da biblioteca escalado (Y/Z pelo diâmetro, X pela tala); lado direito girado 180° no eixo vertical.
   - Disco e pinça universais do jogo (malhas simples geradas/incluídas), pinça com a cor configurada.
   - Offset e cambagem: só **visuais** (não mexem na física).
7. **Altura (stance)**: deslocar a carroceria em relação às rodas; expor o valor para a física usar na Etapa 04.
8. **Showroom de teste**: plataforma giratória, câmera orbital (mouse e analógico direito), HDRI, painel de debug com botões para: trocar cada slot, cada acabamento de pintura, cor, roda, tamanho de aro, tala, cambagem, altura; botão "salvar no perfil de teste" (usa `SaveManager`) e "recarregar".
9. **Desempenho**: montar um carro já em cache em < 50 ms; trocar uma peça em < 5 ms; nenhuma malha duplicada na memória para peças iguais.
10. Capturas com `screenshot.sh` de cada acabamento de pintura (anexar no PR).

## Critérios de aceite
### 🤖 Automáticos
- [ ] Teste: montar a fixture com a config padrão → nenhum aviso; todas as peças `stock` visíveis, demais escondidas.
- [ ] Teste: trocar cada slot da fixture para cada variante → visibilidade correta; `hides` respeitado.
- [ ] Teste: materiais por nome mapeados corretamente; materiais compartilhados são a mesma instância entre dois carros.
- [ ] Teste: diâmetro externo do pneu constante ao trocar o aro de 15" para 22".
- [ ] Teste: config salva e recarregada reproduz exatamente o mesmo carro.
- [ ] Shaders compilam nos dois renderizadores (rodar showroom em Compatibility no CI via captura).
### 🎮 Manuais
- [ ] O dono acha a pintura bonita no showroom (é o primeiro "uau" do projeto).

## Armadilhas
- Escala negativa para espelhar rodas: evitar (usar rotação de 180°).
- Criar `ShaderMaterial` novo a cada troca de cor (vazamento de memória): reutilizar a instância e só mudar uniforms.

## Fora do escopo
Vinis, neon, placa, faróis coloridos (Etapa 08). Física (Etapa 04).
