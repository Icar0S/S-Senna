# Etapa 07 — Dois controles e tela dividida

> **Marco:** C · **Depende de:** 04 · **Tamanho:** G
> **Resultado:** dois jogadores, cada um com seu controle, dirigem ao mesmo tempo no Campo Plano em tela dividida — o grande diferencial do jogo.

## Objetivo
Completar o `InputRouter` e criar a tela dividida, a entrada de jogadores, a seleção simultânea de carros e o
remapeamento de botões por jogador.

## Entregáveis
- `core/input/input_router.gd`, `player_slot.gd`, `device_registry.gd`, `input_actions.gd`, `input_glyphs.gd`.
- `game/split_screen/split_screen_layout.tscn` + `player_view.tscn`.
- Tela "Pressione A/✕ para entrar" (join), seleção simultânea de carro e perfil, tela de controles por jogador.
- Ajustes automáticos de qualidade em tela dividida.

## Controles padrão
| Ação | Controle (Xbox / PlayStation) | Teclado J1 | Teclado J2 (teclado compartilhado) |
|---|---|---|---|
| Acelerar | RT / R2 | W | ↑ |
| Frear / Ré | LT / L2 | S | ↓ |
| Direção | Analógico esquerdo / D-pad | A / D | ← / → |
| Nitro | A / ✕ | Shift esquerdo | Shift direito |
| Freio de mão | X / □ | Espaço | Ctrl direito |
| Trocar câmera | Y / △ | C | End |
| Olhar para trás | B / ○ | Q | Delete |
| Marcha − / + (manual) | LB / RB (L1 / R1) | Z / X | Page Down / Page Up |
| Reposicionar carro | Back / Share (segurar) | R | Backspace |
| Pausa | Start / Options | Esc | — |
| Menus | D-pad/analógico + A/✕ confirmar, B/○ voltar | setas + Enter/Esc | — |

Todos remapeáveis por jogador (Etapa 07, tela de controles).

## Design técnico
### Dispositivos e jogadores
- `DeviceRegistry` lista dispositivos como chaves `kbd`, `kbd_left`, `kbd_right` (teclado inteiro ou dividido) e `joy:<id>`; observa `Input.joy_connection_changed`.
- ⚠️ Teclado e o primeiro controle podem ter `device == 0`: a chave sempre combina **tipo do evento + device**.
- Controles lembrados pelo **GUID** (`Input.get_joy_guid`) em `input.json` → ao reabrir o jogo, o mesmo controle volta a ser o Jogador 2.
- `DeviceRegistry` tem um "provedor falso" para testes (não dá para plugar controles reais no CI).

### Ações por jogador
- `InputActions` define a lista base (`throttle`, `brake`, `steer_left`, `steer_right`, `nitro`, `handbrake`, `camera`, `look_back`, `shift_up`, `shift_down`, `reset`, `pause`, `ui_*`).
- O `InputRouter` cria em tempo de execução `p1_<ação>` e `p2_<ação>` no `InputMap`, com eventos filtrados pelo `device` atribuído (ou teclas do lado do teclado).
- API: `InputRouter.get_axis(player, neg, pos)`, `is_pressed(player, action)`, `just_pressed(...)`, `assign(player, device)`, `release(player)`; sinais `player_joined`, `player_left`, `device_lost(player)`.

### Tela dividida
- `SplitScreenLayout` cria 1 ou 2 `PlayerView` (`SubViewportContainer` + `SubViewport` + `ChaseCamera` + HUD) **compartilhando o mesmo mundo 3D**.
- Layout **horizontal** (cima/baixo, padrão) ou **vertical** (lado a lado) — configuração `video.split_layout`.
- HUD escala pelo tamanho do viewport.
- **Menus independentes** (ex.: seleção de carros simultânea): cada jogador tem sua própria `SubViewport` com **foco de UI próprio**; o `InputRouter` encaminha só os eventos do dispositivo daquele jogador usando `_propagate_input_event` do `SubViewportContainer` e/ou `push_input`.
- Pausa: quem pausou controla o menu de pausa.

### Áudio em tela dividida
- O motor do **próprio carro** de cada jogador toca de forma não posicional (estável, levemente puxado para o lado/altura da sua tela); os demais carros são 3D em relação ao ouvinte mais próximo.
- Testar e ajustar para não ficar "dobrado".

### Desempenho em tela dividida
- Preset automático "dividida": sombras com menos distância/resolução, *LOD bias* maior, menos partículas, *render scale* opcional (FSR).
- Meta: 60 FPS no hardware recomendado, 30+ no mínimo.

### Fluxo de jogo a dois
```
Menu principal → "Jogar a dois" → J2 aperta A/Start no controle (ou tecla no teclado)
  → J2 escolhe: [Meu perfil] [Convidado]
  → Seleção simultânea de carros (cada um na sua metade da tela)
  → Escolha de pista/modo (controlada pelo J1)
  → Corrida em tela dividida
```
- **Convidado** usa carros "emprestados" da garagem do J1 ou da Concessionária (sem salvar progresso).
- Com perfil próprio, o J2 ganha dinheiro/reputação no perfil dele.

### Desconexão
- Controle desconectado no meio da corrida → pausa com "Reconecte o controle do Jogador 2 ou aperte A em outro controle".

### Vibração
- `Input.start_joy_vibration` por jogador: batidas, zebras, nitro, limitador. Opção para desligar.

### Ícones de botões
- `InputGlyphs` escolhe ícones Xbox / PlayStation / Switch / teclado (Kenney Input Prompts, CC0) conforme o dispositivo de cada jogador — cada metade da tela mostra os ícones do **seu** controle.

## Tarefas
1. `DeviceRegistry` (+ provedor falso), `InputActions`, `InputRouter` completo.
2. Persistência em `input.json` (bindings e GUIDs).
3. `PlayerView` e `SplitScreenLayout` (1↔2 jogadores sem recarregar a cena).
4. Tela de entrada de jogadores, seleção simultânea de carro/perfil, tela de controles (remapear, testar vibração, restaurar padrão).
5. Campo Plano com 2 jogadores.
6. Preset de qualidade automático para tela dividida.
7. Áudio por jogador.
8. Tratamento de desconexão.

## Critérios de aceite
### 🤖 Automáticos
- [ ] Teste: eventos de `joy:0` e `joy:1` vão para jogadores diferentes; teclado (`device 0`) não se confunde com `joy:0`.
- [ ] Teste: teclado dividido (J1 WASD, J2 setas) funciona simultaneamente.
- [ ] Teste: remapeamento salvo e recarregado.
- [ ] Teste: menu na `SubViewport` do J2 não recebe eventos do J1.
- [ ] Teste: cena com 2 veículos, 2 câmeras e 2 HUDs, cada HUD mostrando seu carro.
- [ ] Captura de tela dividida horizontal e vertical anexada ao PR.
### 🎮 Manuais (dono)
- [ ] **Dois controles diferentes** (ex.: Xbox + DualSense) dirigindo juntos no Campo Plano.
- [ ] Desconectar e reconectar o controle do J2 no meio do teste.
- [ ] FPS aceitável no PC do dono em tela dividida.

## Armadilhas
- **Steam Input** pode "sequestrar" controles quando o jogo roda pela Steam: documentar no README como desativar.
- Usar `Input.is_action_pressed("throttle")` genérico em qualquer lugar quebra o multi-jogador: sempre passar pelo `InputRouter`.

## Fora do escopo
Mais de 2 jogadores (a arquitetura permite, mas não é meta da 1.0).
