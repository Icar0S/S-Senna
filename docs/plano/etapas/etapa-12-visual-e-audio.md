# Etapa 12 — Identidade visual "PS2+", efeitos e áudio

> **Marco:** E · **Depende de:** 11 · **Tamanho:** G
> **Resultado:** o jogo tem cara própria — noite molhada, neon, bloom, sensação de velocidade — e som de motor que dá vontade de acelerar. Tudo rodando leve.

## Objetivo
Polir a apresentação audiovisual sem fugir do orçamento de desempenho, e criar presets de qualidade que funcionem do PC fraco ao forte.

## Entregáveis
- Presets de ambiente (`WorldEnvironment`) por pista/hora: tonemapping (AgX ou Filmic), glow forte, névoa, correção de cor (LUT), céu.
- Efeitos de carro: rastros de luz das lanternas, cones de farol falsos, faíscas, fumaça de pneu, chamas de escapamento (*backfire*), gotas/spray em pista molhada.
- Efeitos de velocidade: desfoque radial no nitro, linhas de velocidade, tremor de câmera, FOV dinâmico.
- Presets de qualidade **Baixo / Médio / Alto / Ultra** + detecção automática na primeira execução + ajustes de tela dividida.
- Sistema de áudio completo: motor, turbo, câmbio, pneus, batidas, vento, UI, ambiente; **rádio**.
- Cena de benchmark.

## Visual
### Carros
- `ReflectionProbe` assadas nas pistas (carros refletem a cidade) + probe de alta qualidade na garagem.
- Brilho do verniz e borda iluminada (rim light) na garagem.
- Faróis: `SpotLight3D` sem sombra (só nos carros dos jogadores no preset Alto) + cone volumétrico falso (malha emissiva aditiva).
- Lanternas com rastro de luz acima de ~120 km/h (fita/ribbon emissiva), estilo NFSU.

### Pista molhada (Centro)
- Rugosidade baixa no asfalto + máscara de poças; reflexos com SSR (só Alto/Ultra, Forward+) e, nos presets baixos, "faixas de reflexo" falsas (decals verticais esticados embaixo das luzes) — o truque clássico da era PS2.

### Pós-processamento por jogador
- Feito com um `ColorRect` de tela cheia em **cada** `PlayerView` usando `hint_screen_texture` — funciona nos dois renderizadores e em tela dividida.

### Presets de qualidade
| Item | Baixo | Médio | Alto | Ultra |
|---|---|---|---|---|
| Renderizador | Compatibility recomendado | Forward+ | Forward+ | Forward+ |
| Sombras | só do sol, curtas | sol | sol + faróis J1/J2 | + mais distância |
| SSR | não | não | sim | sim |
| Glow | simples | sim | sim | sim |
| Partículas | mínimas | médias | completas | completas |
| Escala de render | 0,75 + FSR1 | 1,0 | 1,0 | 1,0 (ou FSR2 qualidade) |
| Distância de visão | curta | média | longa | máxima |

- Tela dividida aplica automaticamente um "degrau abaixo" em sombras/partículas/distância.
- Primeira execução: benchmark de ~3 s escolhe o preset.

## Áudio
### Motor
- Para cada perfil (`sound.json`): loops de RPM com e sem carga; **crossfade por RPM** + pitch; transição suave ao tirar o pé.
- Turbo (spool com a carga), blow-off ao aliviar, estalos de escapamento em redução, limitador.
- Perfis iniciais: I4 aspirado, I4 turbo, I6 turbo, V6, V8, Boxer, Rotativo (fontes CC0 ou gravadas pelo dono, créditos em `CREDITS.md`).

### Demais sons
- Pneus: chiado proporcional ao escorregamento; mudança de som por superfície (asfalto, zebra, terra).
- Batidas por intensidade do impacto; raspadas em muros.
- Vento com a velocidade; ambiente da cidade à noite; reverb em túneis (`Area3D` com bus de reverb).
- Efeito Doppler nos carros que passam.

### Rádio
- Faixas incluídas (CC0/CC-BY com créditos).
- **Pasta de músicas do jogador** (OGG/MP3/WAV), escolhida nas Opções; playlists "Garagem" e "Corrida"; pular faixa; aviso com nome da música ao trocar (estilo NFSU).
- Buses: Master, Música, Efeitos, Motor, UI — volumes nas Opções.

## Benchmark
- `game/sandbox/benchmark.tscn`: percurso de câmera fixo no Centro com 8 carros e (opção) tela dividida; registra FPS médio, 1% mínimo e draw calls em `<saves>/logs/benchmark.json`.
- Linha de base registrada no PR; regressões > 10% precisam de justificativa.

## Critérios de aceite
### 🤖 Automáticos
- [ ] Todos os shaders compilam em Forward+ e Compatibility (capturas nos dois).
- [ ] Mudança de preset em tempo real sem reiniciar (exceto troca de renderizador, que pede reinício).
- [ ] Sistema de motor: com RPM variando de 1000 a 8000, a soma dos volumes dos loops é aproximadamente constante (sem "buracos").
- [ ] Rádio lê uma pasta de teste com OGG e MP3.
### 🎮 Manuais
- [ ] O Centro à noite "parece Underground" sem copiar nada.
- [ ] Benchmark no PC do dono atinge as metas de `00-visao-do-jogo.md` §6.
- [ ] O som do motor muda de forma convincente entre perfis.

## Fora do escopo
Clima dinâmico e ciclo dia/noite em tempo real (futuro).
