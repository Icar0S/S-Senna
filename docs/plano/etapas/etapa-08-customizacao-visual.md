# Etapa 08 — Customização visual completa

> **Marco:** D · **Depende de:** 03, 06 · **Tamanho:** G
> **Resultado:** todos os sistemas de visual funcionando: bodykits com regras, peças universais, rodas completas, pintura avançada, **vinis em camadas**, vidros, faróis, neon, placa, altura, nota visual.

## Objetivo
Implementar a lógica e a renderização de **toda** a customização visual. A interface bonita da garagem vem na Etapa 09;
aqui cada sistema é testado num **painel de debug** no showroom (e reaproveitado no Studio).

## Entregáveis
- `core/vehicle/part_rules.gd` (regras de peças), `vinyl_compositor.gd`, `neon.gd`, `plate_renderer.gd`, `style_rating.gd`, `look_presets.gd`.
- Atualização do `car_paint.gdshader` com vinis.
- Biblioteca inicial: 10 aerofólios, 4 lips, 3 difusores, 2 pares de canards, 3 entradas de ar, 6 ponteiras, 15 aros, 60 vinis (SVG; o agente pode desenhar programaticamente listras, números, formas, chamas simples).
- Showroom de debug com todos os controles.

## Sistemas

### 8.1 Bodykits e regras
- `PartRules.can_install(config, part) -> Result` e `install(config, part) -> CarConfig` (função pura): aplica `hides`, verifica `requires` e `conflicts` e explica o motivo quando não pode ("Este capô já tem entrada de ar").
- Acabamento por peça: **pintado** (cor do carro), **carbono**, **preto fosco** (onde `finishes` permitir).
- Ajustes finos de peças universais: altura do aerofólio (`part_fit.spoiler.height_m`), dentro de limites.
- Widebody: variante de `body` que pode exigir/ocultar `fenders` e aumentar `width_in_max`/`max_offset_mm`.

### 8.2 Rodas
- Biblioteca com filtro por estilo; aro **dianteiro e traseiro independentes** (opcional "mesmo nas 4").
- Diâmetro (15"–22", limitado pelo carro), tala, offset, cambagem (visuais), duas zonas de pintura (`rim`, `rim_accent`), cor da pinça.
- Opção divertida: **spinners** (aros com `spinner: true` continuam girando devagar com o carro parado).
- Pneu: textura de lateral (com letras genéricas opcionais, "S-SENNA RACING").

### 8.3 Pintura
- 8 acabamentos (`03-formatos-de-dados.md` §9); zonas `paint_body`, `paint_secondary`, `trim_black` ("pintar na cor do carro"), rodas, pinças.
- Seletor de cor: roda HSV + paleta de presets + **"minhas cores"** salvas no perfil + conta-gotas (pegar a cor de outra zona).

### 8.4 Vinis em camadas (ADR 007)
- **Cinco telas 2D**, uma por lado: esquerda, direita, topo (capô/teto/porta-malas), frente, traseira.
- `VinylCompositor`: para cada lado, uma `SubViewport` 2D (1024×512 para laterais, 1024×1024 para topo, 512×512 frente/trás) onde cada camada é um `Sprite2D` com a máscara do vinil, cor(es), posição, escala, rotação e espelhamento.
- O shader de pintura projeta cada textura no carro por **projeção de caixa no espaço do carro** (usando a bounding box do carro), com máscara pela normal (cada lado só pinta superfícies voltadas para ele) e suavização nas transições.
- Aplicado só aos materiais `paint_body` (e opcionalmente `paint_secondary`).
- "Espelhar lado esquerdo no direito" (padrão ligado), duplicar camada, ordem das camadas, até **32 camadas por lado**.
- Ao sair do editor de vinis, as texturas são **"assadas"** (copiadas para `ImageTexture`) e as `SubViewport` liberadas — custo zero durante a corrida.
- Fundo do editor: silhueta do carro renderizada em câmera ortográfica daquele lado (o jogador vê onde está colando).
- Edição **pensada para controle**: analógico esquerdo move, direito gira/escala, gatilhos trocam camada; mouse também funciona.
- Vinis de **texto livre** (fonte OFL, o jogador digita).
- Peças específicas exportadas "no lugar" (doc 04) recebem os vinis corretamente; universais não.

### 8.5 Vidros, luzes, neon e placa
- Insulfilme: cor + escurecimento.
- Cor do farol (presets 4300K, 6000K, 8000K + cores), luzes de freio/ré já existentes.
- **Neon**: cor, modo (fixo, pulsar, respirar, arco-íris); implementado com `Decal` emissivo projetado no chão (barato) + tubo emissivo; luz real opcional só no preset Alto.
- **Placa**: texto livre (até 8 caracteres) em placa **genérica** estilizada (não reproduzir placas oficiais); renderizada numa textura pequena.

### 8.6 Altura e postura
- Altura de rodagem (afeta visual e, levemente, a suspensão), já integrada à física da Etapa 04.

### 8.7 Nota visual e presets
- `StyleRating`: soma dos `style_points` de peças, rodas, vinis, neon etc. → **0 a 10 estrelas** (usado na carreira, Etapa 13).
- **Looks**: salvar o visual inteiro como preset no perfil e aplicar depois; botão **"Aleatório"** (gera visuais coerentes — também usado nos carros da IA).
- Preset **"Versão da minha miniatura"** (completo, agora com vinis), editável no Studio.

## Tarefas
1. `PartRules` + testes.
2. Rodas completas + spinners.
3. Pintura completa + seletor de cor.
4. `VinylCompositor`, shader com projeção, editor de vinis (no showroom de debug; UI final na Etapa 09).
5. Vidros, faróis, neon, placa.
6. `StyleRating`, looks, aleatório.
7. Biblioteca inicial de peças/aros/vinis (modelos simples gerados por script ou feitos no Blender com o add-on).
8. Integração no Studio: editor de "Versão da minha miniatura" e pré-visualização de vinis.
9. Teste de desempenho: carro com 32 camadas por lado + neon + spinners em tela dividida.

## Critérios de aceite
### 🤖 Automáticos
- [ ] `PartRules`: hides/requires/conflicts com mensagens corretas.
- [ ] `CarConfig` com todos os recursos (vinis em 5 lados, neon, placa, rodas diferentes) faz ida e volta pelo save sem perdas.
- [ ] Vinil espelhado aparece na posição espelhada.
- [ ] Gerar visual aleatório 1000 vezes nunca produz config inválida.
- [ ] Capturas: 6 visuais bem diferentes do mesmo carro anexadas ao PR.
### 🎮 Manuais
- [ ] Fazer um visual completo estilo "Underground" com o controle, do zero.
- [ ] Recriar a pintura de uma miniatura da coleção.

## Armadilhas
- Projeção de caixa estica o vinil em superfícies muito inclinadas: suavizar pela normal e aceitar como estilo "PS2".
- Esquecer de liberar as `SubViewport` após assar os vinis (memória e GPU desperdiçadas).

## Fora do escopo
A interface final da garagem (Etapa 09).
