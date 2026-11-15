# Etapa 10 — Performance simplificada e ajustes (tuning)

> **Marco:** D · **Depende de:** 04, 09 · **Tamanho:** M
> **Resultado:** deixar o carro mais rápido e mais fácil de pilotar é simples e satisfatório — sem planilhas de relação de marcha.

## Objetivo
Como pedido pelo dono: a parte de motor **não precisa ser complexa**. No fim, o jogador quer o carro mais rápido, forte e
fácil de pilotar. Então: **níveis de upgrade**, **poucos ajustes com nomes claros** e um botão **"deixar no máximo"**.

## Entregáveis
- Menu **Performance** na garagem.
- `upgrades.json` completo (doc 03 §12) e integração com o `HandlingModel`.
- Índice de desempenho (**PI**) e classes.
- Painel de ajustes simples e botão de acerto automático.

## Design
### 10.1 Upgrades em níveis
| Categoria | Níveis | O que muda (resumo para o jogador) |
|---|---|---|
| Motor | Stock → Rua → Pro → Elite | Potência |
| Turbo/Compressor | idem | Potência e torque |
| Câmbio | idem | Trocas mais rápidas |
| Suspensão | idem | Controle nas curvas |
| Pneus | idem | Aderência |
| Freios | idem | Frenagem |
| Nitro | idem | Duração do nitro |
| Redução de peso | idem | Aceleração e controle |

- Ao navegar, barras de stats mostram **antes/depois** (verde/vermelho).
- Botão **"Comprar tudo no máximo"** (com preço total) e, no Modo Colecionador, "Máximo grátis".
- Upgrades visuais ligados ao desempenho (opcional, divertido): nível Elite de turbo libera som de *blow-off* mais forte.

### 10.2 PI e classes
- `PerformanceIndex.compute(params) -> int` (100–999) a partir de potência/peso, aderência, frenagem e velocidade máxima.
- Classes: **D** (< 400), **C**, **B**, **A**, **S** (≥ 800), **S+** (≥ 900). Limites em `economy.json`.
- Eventos podem exigir classe máxima (Etapa 11/13).

### 10.3 Ajustes (sliders com nomes claros)
| Ajuste | Esquerda ↔ Direita | Afeta |
|---|---|---|
| Direção | Suave ↔ Rápida | velocidade de esterço / sensibilidade |
| Comportamento | Aderência ↔ Drift | aderência traseira relativa |
| Freio | Dianteiro ↔ Traseiro | distribuição |
| Câmbio | Aceleração ↔ Velocidade final | relação final |
| Aerodinâmica | Velocidade ↔ Curvas | downforce × arrasto |
| Nitro | Curto e forte ↔ Longo e suave | força × duração |

- Botões de **acerto automático**: "Circuito", "Drift", "Drag", "Equilibrado".
- Mostrar uma frase simples do efeito ("Mais fácil de fazer drift, menos estável em curvas rápidas").

### 10.4 Dinamômetro (opcional, cosmético)
- Gráfico simples de potência × RPM antes/depois do upgrade (desenhado com `Line2D`). Puro charme.

### 10.5 Assistências (por jogador, no perfil)
- ABS, controle de tração, estabilidade, direção assistida, câmbio auto/manual, linha de corrida (Etapa 11). Pré-ajustes "Iniciante / Normal / Experiente".

## Critérios de aceite
### 🤖 Automáticos
- [ ] Cada nível de upgrade melhora o stat correspondente (monotonicidade) e nunca piora os outros acima de uma margem definida.
- [ ] PI cresce com upgrades; classes respeitam os limites.
- [ ] Acerto "Drift" aumenta o ângulo médio de drift no teste de física de skidpad; "Circuito" reduz o tempo de volta no circuito de teste (comparação headless).
- [ ] Carro no máximo continua estável no slalom do Campo Plano com assistências padrão.
### 🎮 Manuais
- [ ] O dono sente a diferença entre Stock e Elite e acha o máximo "rápido, forte e fácil".

## Fora do escopo
Peças individuais de motor (pistões, comando etc.) — intencionalmente fora do jogo.
