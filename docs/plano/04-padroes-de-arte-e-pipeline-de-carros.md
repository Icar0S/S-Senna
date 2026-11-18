# 04 — Padrões de Arte e Pipeline de Carros

Este é o documento mais importante para o objetivo principal do dono: **colocar no jogo os carros da coleção de miniaturas**.
Ele define como um carro deve ser modelado, organizado e exportado para entrar no jogo sem dor de cabeça.

---

## 1. Visual "PS2+" — o que isso significa em números

A geração PS2 usava carros de ~3–6 mil polígonos. Nós miramos um pouco acima ("PS2+ / começo do PS3"),
o que ainda é **5 a 10 vezes mais leve** que um carro de jogo atual, mas fica bonito com bons reflexos.

| Item | Triângulos (LOD0) | Texturas | Observações |
|---|---|---|---|
| Carroceria + peças originais | 15k – 35k | quase nenhuma (o shader faz a pintura); detalhes em atlas até 1024² | |
| Cada peça de kit | 0,5k – 4k | — | |
| Aro de roda | 1,5k – 4k | opcional 512² | modelado uma vez; o jogo usa nas 4 rodas |
| Pneu | gerado pelo jogo | lateral 512² (do jogo) | o modelador não faz pneu |
| Disco e pinça de freio | do jogo (universais) | — | o modelador não faz |
| Interior | 1k – 3k | 512² | vidros escurecidos escondem o interior simples |
| **Carro montado completo** | **≤ 45k** | | limite verificado pelo validador |
| Cenário visível por câmera | ≤ 600k | atlas 2048² | |

Regras de textura: PNG na fonte, **máximo 2048²** (preferir 1024²), mipmaps ligados, o Godot comprime na importação.
Nada de 4K.

### Truques que dão o visual bonito com poucos polígonos
- **Sombreamento suave + Weighted Normal** (modificador do Blender): reflexos limpos em malhas simples — o maior ganho visual por esforço.
- Linhas de porta/capô: pequenos recortes na malha **ou** omitidas (o reflexo da pintura já "vende" o carro).
- Caixas de roda e frestas por dentro com material `trim_black` (esconde o vazio).
- Faróis e lanternas com material `light_*` + `glass_light` por cima: brilham à noite com o bloom.
- Grade, emblemas genéricos e detalhes finos: material `tex_*` com textura pequena com transparência.

---

## 2. Convenções no Blender (obrigatórias)

| Item | Regra |
|---|---|
| Unidades | Métrico, escala 1,0 (1 unidade = 1 metro) |
| Frente do carro | aponta para **−Y** (a vista Frontal, Numpad 1, mostra a frente do carro) |
| Lado esquerdo do carro | **+X** (lado do motorista em carros de mão inglesa é irrelevante: "esquerda" = esquerda de quem está sentado dentro olhando para frente) |
| Para cima | **+Z** |
| Chão | os pneus tocam **Z = 0** |
| Origem do carro | no chão, no meio da distância entre-eixos e no meio da largura |
| Transformações | aplicadas (Ctrl+A) em todas as malhas — o add-on faz isso automaticamente na exportação |
| Nomes | conforme `03-formatos-de-dados.md` §4.3 (ex.: `bumper_front-kit01`, `socket-spoiler`, `wheel-FL`) |
| Materiais | só os nomes da lista oficial (`paint_body`, `chrome`, `glass`…) ou `tex_<nome>` |
| Duplicados | nada de sufixos `.001` — o validador bloqueia |

> Conversão automática: Blender (frente −Y, Z para cima) → glTF (+Y para cima) → Godot com a frente em **+Z** e a esquerda em **+X**
> (`Vector3.MODEL_FRONT` e `Vector3.MODEL_LEFT`). O código do veículo usa essa convenção; não "girar na mão".

### 2.1 Peças específicas do carro
- Ficam **no mesmo arquivo** do carro, na posição exata em que se encaixam ("modeladas no lugar").
- Cada variante é um objeto separado: `bumper_front-stock`, `bumper_front-kit01`, `bumper_front-kit02`.
- Dica de produtividade: **criar a variante duplicando a peça original** e alterando a forma (botão "Criar variante" do add-on).
- Meta de variedade por carro: 2–3 variantes de para-choques dianteiro e traseiro e de saias; 1–2 de capô; aerofólio original + universais.

### 2.2 Soquetes (onde peças universais e efeitos se prendem)
- São *Empties* com a mesma orientação do carro (frente −Y, cima +Z), posicionados no ponto de fixação.
- Propriedades personalizadas úteis: `width_m` (aerofólio, lips), `length_m`/`width_m` (neon).
- Pares esquerda/direita: criar o esquerdo e usar "Espelhar L→R" do add-on.

| Soquete | Onde fica |
|---|---|
| `socket-spoiler` | centro da tampa traseira, onde a base do aerofólio encosta |
| `socket-exhaust_L` / `_R` | saída do escapamento, apontando para trás |
| `socket-lip_front` / `socket-lip_rear` | borda inferior do para-choque, no centro |
| `socket-canard_L` / `_R` | lateral do para-choque dianteiro |
| `socket-hood_scoop` / `socket-roof_scoop` | centro do capô / do teto |
| `socket-plate_front` / `socket-plate_rear` | centro da placa |
| `socket-neon` | centro do assoalho (com `length_m` e `width_m`) |
| `socket-cam_hood` / `socket-cam_bumper` | posição das câmeras de capô e para-choque |
| `socket-light_head_L/R`, `socket-light_tail_L/R` | centro dos faróis/lanternas (luzes e rastros de luz) |

### 2.3 Rodas
- *Empties* `wheel-FL`, `wheel-FR`, `wheel-RL`, `wheel-RR` no **centro do cubo** de cada roda.
- O botão "Detectar rodas" do add-on calcula centro e raio a partir das malhas de roda selecionadas e cria os empties.
- Opcional: manter **um** aro original como `rim-stock` (o add-on normaliza para o padrão da seção 2.4).
- Os pneus, discos e pinças **não são modelados**: o jogo gera/coloca.

### 2.4 Aros (biblioteca de rodas)
- Modelados em **18" de diâmetro × 8" de tala** (0,4572 m × 0,2032 m), eixo de rotação no eixo **X**, face externa virada para **+X**.
- Origem no **centro geométrico** do aro (meio da tala, no eixo).
- O jogo escala o aro para o tamanho escolhido (15"–22", tala 7"–11") e gira 180° para o lado direito.
- Materiais: `rim`, `rim_accent` (borda/lip), `chrome`, `metal_dark`.

### 2.5 Peças universais
- Origem no **ponto de fixação** (o mesmo ponto do soquete correspondente), mesma orientação do carro.
- Aerofólios e lips modelados com uma **largura de referência** (`reference_width_m`, ex.: 1,40 m); o jogo estica de 85% a 115% para caber no soquete.
- Sem vinis em peças universais (só cor/acabamento).

---

## 3. As quatro rotas para conseguir a malha de um carro

Escolha por carro. Dá para misturar (ex.: IA para a forma geral + modelagem para as peças).

| Rota | Como | Tempo típico* | Qualidade | Quando usar |
|---|---|---|---|---|
| **A. Modelar com blueprints** | Planos de referência nas dimensões reais + modelagem *box/poly* | 15–40 h no começo; 8–20 h com prática | ⭐⭐⭐⭐ controle total | Carros favoritos, os "heróis" da coleção |
| **B. IA imagem→3D + limpeza** | Fotos da miniatura/carro real → ferramenta de IA → retopologia/limpeza no Blender → separar peças | 4–10 h | ⭐⭐⭐ forma boa, detalhes ruins | Encher a concessionária mais rápido |
| **C. Modelo de terceiros licenciado** | Modelo CC0/CC-BY **feito pelo autor** → adaptar às convenções com o add-on | 2–6 h | depende | Quando existir algo com licença clara |
| **D. Fotogrametria da miniatura** | 60–150 fotos ao redor da miniatura → RealityScan/Meshroom → limpeza | 6–12 h | ⭐⭐ (brilho atrapalha) | Miniaturas grandes (1:18, 1:24) e foscas |

\* Ordem de grandeza para um hobbyista; serve só para planejar.

⚠️ **Proibido**: modelos extraídos ("ripados") de outros jogos, mesmo que estejam disponíveis de graça na internet.

### 3.1 Como fotografar uma miniatura para referência
1. Fundo liso, luz difusa (dia nublado ou caixa de luz), uma régua milimetrada ao lado.
2. Câmera **longe com zoom** (reduz distorção de perspectiva).
3. Seis vistas retas (frente, trás, esquerda, direita, cima, baixo) + 3/4 dianteira e traseira + close de rodas, faróis, lanternas e grade.
4. Anotar a **escala** (1:64, 1:43, 1:24, 1:18) e a marca da miniatura (vai para a ficha "Coleção").
5. Usar as **dimensões reais do carro** (ficha técnica do fabricante) como verdade — a miniatura serve para forma, detalhes e pintura.

### 3.2 A pintura da sua miniatura
Cada carro pode ter um preset **"Versão da minha miniatura"** (`collection.livery_preset`): a pintura e os vinis que imitam a
miniatura da estante. Na Concessionária, o jogador pode comprar o carro já com essa pintura.

---

## 4. Passo a passo de um carro (do Blender até a Concessionária)

> Os passos 3–11 estão detalhados no guia [`docs/guias/adicionar-carro.md`](../guias/adicionar-carro.md) (Etapa 05); os passos 12–14 entram nele na Etapa 06.

1. **Abrir uma issue "Novo carro"** (formulário do GitHub): carro real, miniatura, dimensões, referências.
2. **Juntar referências**: blueprints, fotos reais, fotos da miniatura.
3. **Blender → painel S-Senna → "Novo carro"**: digitar comprimento, largura, altura e entre-eixos; escolher as imagens de referência. O add-on cria a estrutura, a caixa-guia e os planos de referência na escala certa.
4. **Fazer a malha** pela rota escolhida (seção 3).
5. **Separar as peças** com "Separar como peça" (escolhe o slot na lista).
6. **Criar variantes de kit** com "Criar variante" e modelar as diferenças.
7. **Materiais**: selecionar faces → escolher o material do jogo na lista.
8. **Soquetes**: criar com o botão e posicionar; "Espelhar L→R".
9. **Rodas**: "Detectar rodas".
10. **Validar**: corrigir tudo que estiver vermelho (amarelo é aviso).
11. **Exportar para o S-Senna**: escolher o pacote; o add-on gera `model.glb` + `carkit_manifest.json`.
12. **S-Senna Studio → "Importar carro"**: ficha (nome, ano, fabricante), stats por preset de categoria, som, preço, dados da coleção, pintura padrão, "versão da miniatura".
13. Studio gera a **foto da vitrine** e você faz o **test drive** no Campo de Provas.
14. **Salvar** → o carro aparece na Concessionária. Commit + PR (o CI valida tudo).

---

## 5. Estratégia de variedade (máximo de opções com o mínimo de trabalho)

A variedade vem da **combinação** de várias camadas independentes:

| Camada | Trabalho | Multiplica |
|---|---|---|
| Kits específicos por carro (para-choques, saias, capô) | por carro | 3 × 3 × 3 × 2 = 54 combinações só com 4 slots |
| Peças universais (aerofólios, lips, canards, entradas de ar, ponteiras) | **uma vez**, servem para todos | cada nova peça aparece em todos os carros |
| Acabamento por peça (pintado / carbono / preto fosco) | zero (é shader) | × 3 por peça |
| Rodas (biblioteca + tamanhos + tala + offset + cambagem + 2 cores) | uma vez | centenas de visuais |
| Gerador procedural de aros (Etapa 15, pode ser antecipado) | uma vez | centenas de aros novos |
| Pintura (8 acabamentos × qualquer cor × 2 zonas) | zero | infinito |
| Vinis em camadas por lado | biblioteca SVG (o agente consegue criar boa parte) | infinito |
| Neon, faróis, vidros, altura, placa | zero | × muito |

Metas da biblioteca universal para a 1.0: **20 aerofólios, 8 lips, 6 difusores, 4 pares de canards, 6 entradas de ar,
10 ponteiras, 30+ aros modelados, 150+ vinis**.

---

## 6. Vinis
- Formato preferido: **SVG** de uma cor (Inkscape), rasterizado pelo jogo no tamanho necessário. PNG para vinis de 2–3 cores (canais R/G/B como máscaras).
- Categorias iniciais: Tribal, Chamas, Listras, Formas, Números, Letras, Respingos, Gradientes, Japonês (kanji genéricos com significado conferido), "Patrocinadores" **fictícios**.
- Vinis de **texto livre** gerados a partir de fontes OFL (o jogador digita).
- Nada de logos reais de marcas.

## 7. Pistas e cenários
- **Kit modular** no Blender: fachadas (3–4 alturas), esquinas, calçadas, postes, placas genéricas, barreiras, árvores simples, outdoors fictícios.
- Estradas com o **Godot Road Generator**; o resto montado no Godot.
- Janelas acesas por **textura emissiva em atlas**; iluminação estática **assada** (LightmapGI); oclusão assada (OccluderInstance3D).
- Itens repetidos (postes, árvores, cones) com `MultiMeshInstance3D`.
- Distância de desenho controlada por *visibility range* (HLOD).

## 8. Interface
- Fontes OFL do Google Fonts (uma display itálica forte para títulos + uma sans legível para textos).
- Ícones de botões: Kenney Input Prompts (CC0) — trocam automaticamente entre Xbox / PlayStation / Switch / teclado.
- Estilo: diagonais, itálicos, contraste alto, cores neon sobre escuro — arte **própria**, sem copiar telas dos jogos de referência.

## 9. Checklist de qualidade de um carro (o validador cobre o que está marcado com 🤖)
- [ ] 🤖 Escala e dimensões batem com `dimensions_mm` (±2%)
- [ ] 🤖 Frente em −Y no Blender, rodas tocando Z = 0
- [ ] 🤖 Nomes e materiais seguem as convenções; sem `.001`; sem sufixos de importação do Godot
- [ ] 🤖 4 âncoras de roda presentes e simétricas (±1 cm)
- [ ] 🤖 Orçamento de triângulos respeitado
- [ ] 🤖 Peças específicas têm variante `stock` para cada slot usado
- [ ] 🤖 Sem faces sem material, sem normais invertidas grosseiras
- [ ] 👀 Reflexo da pintura limpo (sem "amassados" de sombreamento)
- [ ] 👀 Variantes de kit encaixam sem buracos visíveis
- [ ] 👀 Rodas cabem nos para-lamas no tamanho máximo configurado
- [ ] 👀 Foto da vitrine bonita
- [ ] 🎮 Test drive: proporções e altura parecem certas
