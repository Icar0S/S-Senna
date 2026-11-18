# Guia — Campo de testes e ajuste da direção

O Campo Plano é onde se dirige o carro para sentir e ajustar a física. É também a cena do **test drive** do
S-Senna Studio (Etapa 06).

```bat
tools\scripts\jogar.bat res://game/sandbox/campo_plano/campo_plano.tscn
```
Outro carro: acrescente `-- --campo-car=car:base/prototipo` (o ID do carro).

## 1. Controles

| Ação | Controle (Xbox / PlayStation) | Teclado |
|---|---|---|
| Acelerar | RT / R2 | W |
| Frear / Ré (segurar parado) | LT / L2 | S |
| Direção | Analógico esquerdo / D-pad | A / D |
| Nitro | A / ✕ | Shift |
| Freio de mão | X / □ | Espaço |
| Trocar câmera (longe, perto, capô, para-choque) | Y / △ | C |
| Olhar para trás | B / ○ | Q |
| Marcha − / + (câmbio manual) | LB / RB | Z / X |
| Reposicionar o carro | Back / Share | R |

O primeiro controle conectado é do Jogador 1 (junto com o teclado). Dois jogadores ao mesmo tempo vêm na Etapa 07.

## 2. O que tem no campo
Reta de **400 m** com marcas a cada 100 m (medir aceleração), **slalom** de cones (derrubáveis), **curva
inclinada**, **skidpad** (círculo de 30 m para testar aderência em curva), **rampas** de 6°, 10° e 15°,
**lombadas** e paredes em volta. O **R** leva o carro para o ponto seguro mais próximo, de pé.

## 3. Telemetria (F1)
Mostra velocidade, RPM, marcha, ângulo de drift, nitro, FPS e, para cada roda: carga (N), ângulo de
escorregamento, patinação e quanto da aderência está sendo usada (100% = no limite).

## 4. Painel de ajuste (F2) — mude a sensação sem programar
- **Este carro**: parâmetros físicos do carro atual (aderência, molas, freios, esterço, assistências…).
  **"Salvar para este carro"** grava em `tuning_overrides` no `car.json` dele.
- **Global**: constantes que valem para todos os carros (`handling_global.json`). **"Salvar como padrão global"**
  grava nesse arquivo.
- **"Desfazer mudanças"** volta ao que estava salvo.

Salvar só funciona rodando do código-fonte (ou no Studio com `--content-dir`): o jogo exportado não altera os
próprios arquivos. Depois de salvar, faça commit dos arquivos alterados.

### Por onde começar a ajustar
| Quer… | Mexa em |
|---|---|
| Mais aderência em curva | `tire_mu` (carro) ou `grip_min`/`grip_max` (global) |
| Traseira mais solta / mais drift | `rear_grip_factor` ↓, `handbrake_grip_factor` ↓ |
| Drift mais fácil de segurar | `drift_assist` ↑, `countersteer` ↑ |
| Carro menos nervoso | `stability` ↑, `steer_speed` ↓ |
| Esterço mais rápido em alta | `steer_falloff_kmh` ↑ |
| Suspensão mais dura / menos inclinação | `suspension_freq_*` ↑, `antiroll` ↑ |
| Frear mais | `brake_force_n` ↑ ou `brake_decel_g_*` ↑ |

## 5. Como a física funciona (resumo)
Cada roda é um raio: mola + amortecedor + barra estabilizadora seguram o carro; a aderência depende da carga na
roda e é dividida entre frear/acelerar e fazer curva (círculo de atrito). O freio de mão solta a traseira para o
drift, e as assistências (estabilidade, contraesterço, ABS, controle de tração) deixam tudo fácil de controlar.
A velocidade máxima sai do equilíbrio entre a potência e a resistência do ar, então bate com o `top_speed_kmh`
do carro. Detalhes: `godot/core/vehicle/` e `docs/plano/etapas/etapa-04-fisica-e-campo-de-testes.md`.
