# Etapa 11 — Pistas e sistema de corridas (com IA)

> **Marco:** E · **Depende de:** 07, 10 · **Tamanho:** G
> **Resultado:** duas pistas com vários traçados, cinco modos de corrida, adversários controlados pela IA e corridas a dois em tela dividida.

## Objetivo
Começar pequeno, como pedido: **duas pistas de testes bem feitas**, cada uma com vários traçados, e um sistema de corrida
sólido que sirva para todas as pistas futuras.

## Entregáveis
- Pista 1 — **Campo de Provas** (dia/fim de tarde): evolução do Campo Plano.
- Pista 2 — **Centro** (noite, asfalto molhado): circuito urbano compacto.
- `RaceManager`, `RaceParticipant`, `Checkpoint`, `RacingLine`, `AIDriver`, `GhostRecorder`.
- Modos: Circuito, Sprint, Drag, Drift, Contra o Relógio.
- Telas: Corrida rápida, configuração de corrida a dois, contagem regressiva, HUD de corrida, pausa, resultados.
- Minimapa por jogador.

## Pistas
### Campo de Provas
| Traçado | Tipo | Descrição |
|---|---|---|
| `circuito` | circuit | 2–3 km, mistura de curvas rápidas, chicane, grampo |
| `circuito_reverso` | circuit | mesmo, sentido inverso (automático) |
| `drag_400` | drag | reta de 400 m (e 800 m) |
| `skidpad` | drift | círculo e oito para drift |
| `livre` | free | passeio livre para testar carros |

### Centro (noite)
| Traçado | Tipo | Descrição |
|---|---|---|
| `circuito` | circuit | ~2,5 km entre quarteirões, avenida larga + ruas estreitas |
| `circuito_reverso` | circuit | inverso |
| `sprint_porto` | sprint | trecho A→B saindo do centro até a zona portuária |
| `drag_avenida` | drag | avenida principal fechada |
| `drift_estacionamento` | drift | estacionamento de vários níveis / pátio |

> Uma pista bem feita gera muitos eventos: traçados, sentido, número de voltas, classe exigida, hora do dia (futuro).

### Produção das pistas
- Estradas: **Godot Road Generator** (MIT) → malha + colisão.
- Cenário: kit modular do Blender (doc 04 §7), `MultiMeshInstance3D` para repetidos.
- Iluminação estática assada (LightmapGI), `ReflectionProbe` assadas nos pontos-chave (carros refletem a cidade), oclusão assada.
- Limites: muros/barreiras com colisão simples; áreas fora da pista com **reposicionamento automático**.
- Pontos de reposicionamento ao longo da linha de corrida.
- Orçamento por viewport: ≤ 600k triângulos e ≤ 1500 draw calls visíveis (medir com o overlay F1).

## Sistema de corrida
- Estados: `PREPARANDO → CONTAGEM → CORRENDO → TERMINADO → RESULTADOS`.
- **Checkpoints** (`Area3D` numerados) obrigatórios em ordem; volta só conta se passou por todos (anti-atalho).
- **Posição**: checkpoints passados + distância ao longo da `RacingLine` (`Curve3D.get_closest_offset`).
- Detecção de **contramão**, reposicionamento (manual e automático se capotado/parado fora da pista por 3 s).
- Tempos por volta, melhor volta, recordes salvos no perfil (`records`).
- **Drag**: largada com contagem de "árvore de luzes", câmbio com indicador de **troca perfeita** (bônus), direção limitada a troca de faixa.
- **Drift**: pontuação = ângulo × velocidade × tempo, com multiplicador por combo; bate na parede = perde o combo.
- **Contra o relógio**: **fantasma** da melhor volta (posição/rotação amostradas a 20 Hz, salvas em `<saves>/ghosts/`).
- Recompensas (dinheiro/reputação) via `Economy`, por posição e modo.

## IA
- Segue a `RacingLine` com ponto-alvo à frente proporcional à velocidade.
- Perfil de velocidade pré-calculado pela curvatura da linha (freia antes das curvas).
- Desvio lateral para ultrapassar e evitar outros carros (raycasts curtos).
- Dificuldade (Fácil / Normal / Difícil) muda aderência efetiva, agressividade e "erro humano"; **rubber band** configurável (pode desligar).
- Usa o **mesmo veículo e física** dos jogadores, só que preenchendo `VehicleInput` pelo `AIDriver`.
- Carros da IA escolhidos da mesma classe do evento com **visual aleatório** (Etapa 08).
- Limites: até 7 adversários sozinho; até 4 IAs + 2 jogadores em tela dividida.

## Corrida a dois
- Configuração: pista, traçado, voltas, nº de IAs, dificuldade, "ajuda para quem está atrás" (catch-up) liga/desliga.
- Resultados mostram os dois jogadores; cada perfil recebe sua recompensa (convidado não salva).

## HUD de corrida (por jogador)
Posição, volta, tempo, melhor volta, velocímetro/conta-giros, marcha, nitro, **minimapa** (linha da pista desenhada a partir da `RacingLine` + pontos dos carros), aviso de contramão.

## Critérios de aceite
### 🤖 Automáticos (headless com física)
- [ ] IA completa 3 voltas em cada circuito sem ficar presa e dentro de uma faixa de tempo esperada.
- [ ] Pular um checkpoint não conta a volta.
- [ ] Cálculo de posição correto em cenários sintéticos (empates, voltas de diferença).
- [ ] Fantasma gravado e reproduzido bate com o percurso original (erro < 0,5 m).
- [ ] Pontuação de drift e bônus de troca perfeita com valores esperados.
### 🎮 Manuais
- [ ] Corrida a dois + 4 IAs no Centro à noite, em tela dividida, com FPS aceitável.
- [ ] A IA é divertida: não trapaceia de forma óbvia, mas não é fácil demais no Difícil.

## Fora do escopo
Mundo aberto, tráfego, polícia.
