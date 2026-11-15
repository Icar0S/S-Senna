# Etapa 04 — Física arcade, câmera e campo plano de testes

> **Marco:** A · **Depende de:** 03 · **Tamanho:** G
> **Resultado:** dá para dirigir o carro protótipo num campo de testes, com teclado ou controle, e a sensação é "fácil e gostosa".

## Objetivo
Criar a física de direção arcade, a câmera e um campo de testes — **já preparados para vários jogadores** (ADR 011).

## Entregáveis
- `core/vehicle/vehicle.gd` (`RigidBody3D`), `wheel_suspension.gd`, `drivetrain.gd`, `handling_model.gd`, `vehicle_params.gd`, `vehicle_input.gd`.
- `core/vehicle/player_driver.gd` (lê ações do `InputRouter`) — o `AIDriver` vem na Etapa 11.
- `core/camera/chase_camera.gd` (perseguição, capô, para-choque, olhar para trás).
- HUD básico por jogador: velocímetro, marcha, barra de RPM, barra de nitro.
- `game/sandbox/campo_plano/campo_plano.tscn`.
- Ferramentas de ajuste ao vivo: **telemetria (F1)** e **painel de ajuste (F2)**.
- `InputRouter` mínimo (1 jogador, teclado + 1 controle) com a interface definitiva da Etapa 07.

## Modelo de física (arcade)
Por roda, a cada passo de física (120 Hz):
1. **Suspensão**: raycast do ponto de fixação para baixo; força = mola × compressão + amortecedor × velocidade de compressão; barra estabilizadora entre as rodas do mesmo eixo.
2. **Carga** na roda = força da suspensão (usada para limitar a aderência).
3. **Longitudinal**: torque do motor distribuído conforme tração (FWD/RWD/AWD com divisão); freio; freio de mão trava as traseiras.
4. **Lateral**: força contrária à velocidade lateral da roda × aderência × carga, **limitada pelo círculo de atrito**.
5. **Drift arcade**: freio de mão ou excesso de esterço em alta reduz a aderência traseira; *drift assist* mantém o ângulo e evita rodar.

No chassi:
- **Downforce** cresce com a velocidade (estabilidade em alta).
- Centro de massa baixo e inércia ajustada (carro não capota à toa).
- **Assistências** (por jogador, salvas no perfil): direção progressiva (menos esterço em alta), contraesterço automático, controle de estabilidade (amortece guinada), ABS, controle de tração, câmbio automático, auto-endireitar no ar e após capotar.
- **Nitro**: força extra + aumento de FOV + efeito visual simples (Etapa 12 melhora).
- **Reset**: botão volta o carro para a pista, de pé, na direção certa (no campo plano: posição segura mais próxima).

## `HandlingModel` — a sensação em um só lugar
Função pura: `HandlingModel.compute(stats, upgrades, tuning, assists) -> VehicleParams`.
- Converte `power_hp`, `torque_nm`, `mass_kg`, `top_speed_kmh`, `grip`, `handling`, `braking`, `drivetrain`, `gears` em parâmetros físicos (curva de torque simplificada, relações de marcha derivadas da velocidade máxima, rigidez de mola, aderência…).
- Constantes globais de "feeling" em `content/packs/base/handling_global.json` (editáveis pelo painel F2).
- **Totalmente coberta por testes.**

## Tarefas
1. `VehicleInput` (struct) + `PlayerDriver` (suaviza esterço no teclado: rampa de entrada e retorno ao centro).
2. `Vehicle`: instancia `CarVisual` via `CarAssembler`, cria 4 `WheelSuspension` nas âncoras, colisão por duas caixas geradas das dimensões (ou malhas `collision-*`), massa e centro de massa.
3. Rodas visuais: posição pela suspensão, rotação pela velocidade, esterço nas dianteiras.
4. `Drivetrain`: RPM, troca automática (com histerese), troca manual (LB/RB), limitador, valores para o áudio.
5. `ChaseCamera`: seguir com suavização, FOV maior com a velocidade, olhar para trás, alternar câmeras (longe, perto, capô, para-choque), evitar atravessar paredes. **Uma câmera por jogador** (nada de câmera global).
6. HUD por jogador como cena independente que recebe o `Vehicle` que deve mostrar.
7. **Campo plano**: chão grande com textura de grade, rampas, lombadas, slalom de cones, curva inclinada, reta de 400 m com marcações a cada 100 m, pista de skidpad (círculo), paredes de contenção.
8. **Telemetria F1**: velocidade, RPM, marcha, carga e escorregamento de cada roda, uso da aderência, ângulo de drift, FPS.
9. **Painel de ajuste F2**: sliders para os parâmetros de `VehicleParams` e de `handling_global.json`; botões "salvar como padrão global" e "salvar para este carro" (gera `tuning_overrides` no `car.json` ou no global). Assim o **dono ajusta a sensação sem programar**.
10. Áudio provisório do motor (um loop com pitch por RPM) — o sistema real vem na Etapa 12.

## Critérios de aceite
### 🤖 Automáticos (testes de física headless com entrada simulada)
- [ ] Parado em terreno plano: deslocamento < 1 cm em 10 s (sem "escorregar").
- [ ] 0–100 km/h dentro de ±15% do esperado pelo `HandlingModel` para o protótipo.
- [ ] Velocidade máxima a ±5% de `top_speed_kmh`.
- [ ] Frenagem de 100 a 0 em distância dentro da faixa esperada.
- [ ] Slalom a 80 km/h com assistências ligadas: não capota, não roda.
- [ ] Carro solto de cabeça para baixo se endireita em < 3 s com a assistência.
- [ ] `HandlingModel`: mais `power_hp` → mais aceleração; mais `grip` → mais força lateral máxima (testes de monotonicidade).
- [ ] Nenhum código de câmera/HUD acessa "o jogador" de forma global (checado por revisão + teste com 2 veículos e 2 câmeras na mesma cena).
### 🎮 Manuais (dono — o mais importante desta etapa)
- [ ] Dirigir com controle: **fácil de controlar, divertido, sensação de velocidade**.
- [ ] Drift com freio de mão é controlável.
- [ ] Ajustar pelo painel F2 e salvar o feeling preferido.

## Armadilhas
- Física a 60 Hz deixa a suspensão instável: manter 120 Hz.
- Usar `basis.z` como frente (convenção `MODEL_FRONT`) — não `-basis.z`.
- Forças aplicadas no ponto errado fazem o carro "pular": aplicar no ponto de contato, com cuidado com a altura.

## Fora do escopo
Dois jogadores ao mesmo tempo (Etapa 07), IA e corridas (Etapa 11), som real (Etapa 12).
