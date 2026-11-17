# game/ — o Jogo

Menus, garagem, corridas, carreira, tela dividida, HUD, pistas e cenas de teste (sandbox).

**Regra de dependência:** `game/` pode usar `core/`, `ui/` e `content/`. Não pode depender do Studio.

| Pasta | Responsabilidade |
|---|---|
| `main_menu/` | Tela de título (provisória na Etapa 00) |
| `garage/` | Garagem hub: concessionária, visual, performance, coleção, fotos |
| `race/` | Corridas: RaceManager, checkpoints, IA |
| `career/` | Carreira e história |
| `split_screen/` | Layout de 1 ou 2 jogadores |
| `hud/` | HUD por jogador |
| `tracks/` | Cenas das pistas e seus assets específicos |
| `sandbox/` | Cenas de teste (showroom, campo plano) — as únicas que o Studio pode instanciar |

Rodar do código-fonte: `tools/scripts/jogar.sh` / `jogar.bat` (ou `godot --path godot`).
