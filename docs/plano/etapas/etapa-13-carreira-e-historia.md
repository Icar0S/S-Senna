# Etapa 13 — Carreira e história

> **Marco:** F · **Depende de:** 09, 11, 12 · **Tamanho:** M
> **Resultado:** uma carreira curta e divertida, com rivais, mensagens e progressão que libera carros e peças.

## Objetivo
Dar motivo para correr e customizar, com uma história **leve** e **orientada a dados** (fácil de expandir depois sem programar).

## Proposta de história (padrão — 🧑 o dono pode trocar tudo)
- **Cenário**: uma metrópole brasileira **fictícia**, à noite. A cena de rua é organizada em "crews" e um ranking de rivais.
- **Você**: chega à cidade com um carro de entrada e uma garagem emprestada por um mecânico veterano (seu mentor).
- **Estrutura**: 5 capítulos; cada capítulo termina com um **rival-chefe** (estilo escada de rivais), com carro e visual temáticos.
- **Tom**: divertido, sem drama pesado; mensagens no celular do jogo (estilo SMS), poucas cenas curtas.
- **Final**: corrida contra o líder da cena no circuito completo do Centro.

## Entregáveis
- `game/career/career_manager.gd`, telas: **Mapa de eventos**, **Celular (mensagens)**, **Perfil do rival**, **Fim de capítulo**.
- Dados em `content/packs/base/career/`: `chapters.json`, `events.json`, `rivals.json`, `messages.json`.
- Escolha do carro inicial (3 opções baratas e diferentes: FWD, RWD, AWD).
- Planilha/notas de balanceamento em `docs/guias/balanceamento.md`.

## Formatos (resumo)
```json
// events.json (exemplo de um evento)
{
  "id": "evt_c1_03",
  "chapter": 1,
  "name_key": "EVT_C1_03",
  "track": "track:base/centro", "layout": "circuito", "laps": 2,
  "mode": "circuit",
  "requirements": { "max_class": "C", "min_style_stars": 0, "events_done": ["evt_c1_01"] },
  "opponents": { "count": 5, "difficulty": "normal", "class": "C" },
  "rewards": { "money": [3000, 1800, 900], "reputation": [120, 70, 30], "unlocks": ["part:base/universal/spoiler/gt_wing_03"] },
  "intro_message": "msg_c1_03"
}
```
- `rivals.json`: nome, apelido, carro (`car_id` + `CarConfig` visual), frase de desafio, evento-chefe.
- `messages.json`: remetente, texto (chave de tradução), gatilho (`after_event`, `chapter_start`…).
- `chapters.json`: ordem, eventos necessários para liberar o chefe, desbloqueios do capítulo.

## Mecânicas
- **Dinheiro** compra carros/peças; **reputação** libera capítulos.
- **Nota visual** (estrelas da Etapa 08) importa: alguns eventos e "convites" exigem estrelas mínimas, e carros bem montados ganham **bônus de reputação** — conecta a customização com a progressão (o pilar do jogo).
- **Ensaio de capa**: ao atingir 8+ estrelas, libera uma sessão de fotos especial no Modo Foto com moldura de "revista" fictícia do jogo.
- Desbloqueios por capítulo: peças, rodas, vinis e carros na Concessionária.
- **Jogar a dois na carreira**: o J2 pode entrar em qualquer evento já liberado como adversário; o progresso da carreira é do J1, o J2 ganha dinheiro/reputação no próprio perfil.
- Modo Colecionador: a carreira continua jogável, mas sem cobrança.

## Cenas de história
- Simples: mensagens no celular + telas com arte 2D/foto do rival e texto.
- Opcional: **Dialogue Manager** (MIT) para diálogos ramificados curtos.
- Todo texto em chaves de tradução.

## Tarefas
1. `CareerManager` (estado no perfil, regras de liberação, recompensas via `Economy`).
2. Telas (mapa, celular, rival, fim de capítulo, créditos).
3. Conteúdo: 5 capítulos × 5–7 eventos usando as 2 pistas e seus traçados; 5 rivais.
4. Balanceamento: script de simulação que verifica se é possível terminar a carreira com as recompensas (sem "grind" obrigatório) e documento com as curvas de preço/recompensa.

## Critérios de aceite
### 🤖 Automáticos
- [ ] Simulação: jogador que termina em 3º lugar em média consegue comprar o necessário para cada capítulo.
- [ ] Nenhum evento referencia pista/traçado/carro inexistente (validador de conteúdo).
- [ ] Liberação de capítulo e de chefe segue as regras (testes com perfis sintéticos).
### 🎮 Manuais
- [ ] Jogar o capítulo 1 inteiro e achar divertido; as mensagens dão contexto sem atrapalhar.

## Fora do escopo
Dublagem, cinemáticas elaboradas, mundo aberto.
