# Etapa 09 — Garagem (hub estilo Midnight Club), Concessionária e economia

> **Marco:** D · **Depende de:** 02, 07, 08 · **Tamanho:** G
> **Resultado:** um único lugar com tudo: comprar carros, escolher o carro, customizar, ver a coleção, tirar fotos e ir para as corridas.

## Objetivo
Criar a **garagem única** (ADR 010) com interface bonita, pensada para controle, e a economia do jogo.

## Entregáveis
- `game/garage/garage.tscn` (cenário 3D + câmera + UI), `garage_controller.gd`, `shop_catalog.gd`, `economy.gd`.
- Telas: Título → Perfis → Garagem (com todos os menus abaixo).
- Tema de UI do jogo (`ui/theme/`), componentes reutilizáveis (lista com miniaturas, barra de stats, barra de ajuda com ícones de botão, diálogo de confirmação, *toast*).
- Modo Foto e tela Coleção.

## Mapa de menus
```
GARAGEM
├── Corridas ─────────────► (Etapa 11: mapa de eventos / corrida rápida / jogar a dois)
├── Meus Carros ──────────► escolher carro atual, renomear, vender, duplicar visual
├── Concessionária ───────► comprar carros (filtros: categoria, classe, fabricante, "da minha coleção")
├── Visual
│   ├── Kits de carroceria ► Para-choque D · Para-choque T · Saias · Capô · Aerofólio · Retrovisores
│   │                        Faróis · Lanternas · Para-lamas/Widebody · Teto · Escapamento
│   │                        Lip · Difusor · Canards · Entradas de ar
│   ├── Rodas ───────────► estilo · aro · tala · offset · cambagem · cores · pinça
│   ├── Pintura ─────────► zona · acabamento · cor
│   ├── Vinis ───────────► lado · camadas · biblioteca · texto
│   ├── Vidros e Luzes ──► insulfilme · cor do farol · neon
│   ├── Altura ──────────► altura de rodagem
│   ├── Placa
│   └── Looks salvos ────► salvar / aplicar / aleatório
├── Performance ──────────► (Etapa 10)
├── Coleção ──────────────► vitrine dos carros da coleção do dono (com dados das miniaturas)
├── Modo Foto
├── Perfil ───────────────► salvar · trocar perfil · exportar/importar save · Modo Colecionador
└── Opções ───────────────► vídeo · áudio · controles · jogo
```

## Funcionalidades
### 9.1 Cenário e câmera
- Garagem 3D low-poly bonita (piso refletivo, neon, prateleiras, luz de estúdio); presets de iluminação (garagem, dia, noite neon).
- Plataforma giratória; câmera orbital no analógico direito; zoom nos gatilhos.
- **Foco automático**: ao entrar em "Aerofólio", a câmera vai para a traseira; "Rodas", para a roda dianteira etc. (posições calculadas pela bounding box da peça/slot).

### 9.2 Comprar e aplicar
- Navegar mostra a peça **já instalada no carro** (pré-visualização); confirmar compra e aplica; voltar desfaz.
- Preço, nota visual (+estrelas), e cadeado com motivo para itens bloqueados ("Desbloqueia no Capítulo 2").
- Peças já compradas para aquele carro ficam livres para trocar de novo (inventário por carro).
- **Modo Colecionador**: tudo liberado e grátis.

### 9.3 Concessionária
- Carro na plataforma, ficha (fabricante, ano, potência, peso, tração), barras de stats (Velocidade, Aceleração, Controle, Frenagem), classe, preço.
- Se o carro tem dados de coleção: selo **"Da minha coleção"** e opção **"Comprar na versão da minha miniatura"**.
- Garagem sem limite de carros (é um jogo de colecionador). Vender devolve 50% (configurável em `economy.json`).

### 9.4 Coleção
- Grade com todos os carros que têm `collection.has_miniature`, foto da miniatura, marca, escala, data e notas; contador "X de Y da coleção no jogo".
- Filtro por marca da miniatura e por escala.

### 9.5 Modo Foto
- Câmera livre limitada ao redor do carro, FOV, profundidade de campo (Forward+), filtros simples, esconder HUD, poses (rodas esterçadas, faróis ligados, neon).
- Salva PNG em `<saves>/photos/` e mostra o caminho.
- Usado também na garagem e (depois) pausando a corrida.

### 9.6 Economia (`economy.json`)
- Dinheiro inicial, fator de venda, preço padrão por slot × fator por categoria/classe do carro, recompensas base por modo (usadas na Etapa 11/13).
- `Economy` é a única classe que mexe em dinheiro (testada); respeita o Modo Colecionador.

### 9.7 Garagem e o Jogador 2
- A garagem é usada **por um perfil de cada vez**; botão "Trocar para Jogador 2" troca o perfil ativo (o J2 customiza os carros dele).
- A seleção simultânea de carros para a corrida acontece na tela dividida (Etapa 07).

### 9.8 UX para controle
- Tudo navegável com controle; barra inferior de ajuda com os ícones do controle de quem está usando.
- Repetição de navegação ao segurar direcional; sons de UI; transições rápidas (< 150 ms).
- Textos traduzíveis (pt_BR e en).

## Critérios de aceite
### 🤖 Automáticos
- [ ] `Economy`: compra com saldo insuficiente falha; venda credita o valor certo; Modo Colecionador não desconta.
- [ ] Pré-visualizar e cancelar não altera o save.
- [ ] Navegação por foco: teste de cena percorre todos os menus só com eventos de controle.
- [ ] Capturas de cada menu anexadas ao PR.
### 🎮 Manuais
- [ ] Comprar um carro, customizar tudo, salvar, fechar, abrir: tudo igual.
- [ ] Usar a garagem inteira só com controle, sem mouse.
- [ ] A tela Coleção mostra corretamente o carro real adicionado na Etapa 06.

## Fora do escopo
Upgrades de performance (Etapa 10), eventos de corrida (Etapa 11).
