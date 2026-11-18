# Adicionar um carro — parte do Blender

Do modelo no Blender até um `model.glb` validado, pronto para o jogo. A segunda parte (ficha, stats, som, preço,
test drive) acontece no **S-Senna Studio** (Etapa 06); até lá, o `car.json` é atualizado por um script (seção 7).

Antes: instale o add-on — [Instalar o add-on do Blender](instalar-addon-blender.md). Os padrões de arte (orçamento de
triângulos, estilo, rotas de modelagem) estão na doc `docs/plano/04-padroes-de-arte-e-pipeline-de-carros.md`.

> Exemplo completo, feito só com os botões do add-on: `tools/blender/make_prototipo_v2.py` gera o
> **Protótipo S-Senna** do pacote base. Rode `tools/blender/make_prototipo_v2.sh --blend ~/prototipo.blend` e abra
> o `.blend` para ver como o carro fica organizado.

## Regras de ouro (o validador confere todas)
- **Frente do carro para −Y**, esquerda em **+X**, para cima **+Z**; as rodas tocam o chão (Z = 0).
- Unidade: **metros**, em escala real.
- Nomes: `<tipo>-<nome>` com hífen (`body-stock`, `bumper_front-kit01`, `socket-spoiler`, `wheel-FL`). Nada de `.001`.
- Materiais: só os nomes da lista do jogo (`paint_body`, `trim_black`, `glass`…) — o jogo troca pelo material real.
- O add-on **nunca altera o seu arquivo** ao exportar: ele trabalha numa cópia.

## 1. Novo carro
Painel **S-Senna → 1. Novo carro**:
1. Digite o **nome (slug)** — letras minúsculas, números e `_` (ex.: `rx7_fd`) — e as medidas reais em mm:
   comprimento, largura (sem retrovisores), altura e entre-eixos.
2. (Opcional) escolha as **imagens de referência** (frente, lateral, traseira, topo).
3. Clique em **Novo carro**. O add-on cria:
   - a coleção `carro-<slug>` com as subcoleções `peças-`, `soquetes-`, `rodas-` e `referências-<slug>`;
   - a **caixa-guia** (aramado) com as dimensões do carro;
   - os planos de referência na escala certa, semitransparentes e não selecionáveis.

Tudo que fica em `referências-<slug>` (guias, imagens, malhas originais das rodas) **não é validado nem exportado**.

## 2. Modelar e organizar
Modele (ou importe e ajuste) o carro dentro da caixa-guia. Depois, painel **2. Ferramentas**:

| Botão | Quando usar |
|---|---|
| **Ajustar escala pelo comprimento** | Modelo importado no tamanho errado: escala a malha ativa para o comprimento digitado (depois aplique com Ctrl+A → Escala) |
| **Separar como peça** | No modo de edição, selecione as faces da peça, escolha o **slot** na lista e clique: vira `<slot>-stock` em `peças-` |
| **Criar variante** | Com uma peça ativa: duplica como `<slot>-kit01` (próximo número livre) e esconde a original; modele as diferenças na cópia |
| **Material do jogo** | Escolha o material na lista; aplica às faces selecionadas (modo de edição) ou ao objeto inteiro |
| **Criar soquete** | Posicione o cursor 3D (Shift+clique direito) e escolha o soquete; largura/comprimento são opcionais (ex.: `spoiler` com a largura da tampa) |
| **Espelhar L→R** | Cria/atualiza o par direito de tudo que termina em `_L` (ex.: `socket-exhaust_L` → `socket-exhaust_R`) |
| **Detectar rodas** | Selecione as **4 malhas de roda** e clique: cria `wheel-FL/FR/RL/RR` no centro de cada uma, com o raio. Se escolher um **Aro original**, ele vira o `rim-stock` normalizado (18" × 8"). As malhas originais vão para `referências-` |
| **Aro máx.** | Mostra/esconde um cilindro fantasma do pneu com o aro e a tala máximos, para conferir o para-lama |

Slots obrigatórios e úteis:
- `body-stock` é obrigatório; todo slot com variantes precisa da `stock`.
- Vidros e interior são partes fixas: `glass-stock`, `interior-stock` (fora de `peças-`, direto na coleção do carro).
- Retrovisores (`mirrors`) e aerofólio (`spoiler`) **não contam** nas medidas do carro, como numa ficha técnica.

## 3. Soquetes recomendados
A falta destes gera aviso amarelo (não bloqueia): `spoiler`, `exhaust_L/R`, `lip_front`, `lip_rear`,
`plate_front`, `plate_rear`, `neon`, `light_head_L/R`, `light_tail_L/R`. A lista completa está em
`godot/core/content/conventions.json` (`sockets`).

## 4. Rodas
- Use malhas de roda (pneu + aro) do próprio modelo ou cilindros simples só para a detecção.
- O jogo gera os pneus; o diâmetro externo do pneu sai do raio detectado.
- "Simetrizar" (ligado) deixa os pares esquerda/direita exatamente espelhados e as rodas tocando o chão.

## 5. Validar
Painel **3. Validar** → **Validar**. Cada item tem um botão para selecionar o objeto. Vermelho bloqueia a exportação;
amarelo é aviso.

| Mensagem (resumo) | Como corrigir |
|---|---|
| nome com sufixo de cópia (`.001`) | Renomeie (F2) |
| nome fora do padrão `<tipo>-<nome>` | Renomeie seguindo a tabela das regras de ouro, ou mova o objeto para `referências-` |
| termina com sufixo de importação do Godot | Não termine nomes com `-col`, `-rigid`, `-wheel`… |
| escala negativa | Ctrl+A → Escala (e confira as normais) |
| rotação/escala não aplicadas (aviso) | O exportador aplica numa cópia; aplicar (Ctrl+A) deixa o arquivo mais previsível |
| material fora da lista / faces sem material | Use **Material do jogo** |
| o carro precisa de `body-stock` / slot sem `stock` | Separe/renomeie a peça original |
| âncoras de roda ausentes / sem raio | Use **Detectar rodas** |
| a roda não toca o chão | O carro está acima/abaixo de Z = 0: mova tudo e detecte as rodas de novo |
| rodas dianteiras atrás das traseiras / carro mais largo que comprido | O carro está virado: a frente deve apontar para −Y |
| rodas da esquerda devem ficar em +X | Carro espelhado (ou de costas): gire 180° em Z |
| rodas não simétricas | Ligue "Simetrizar" e detecte de novo |
| comprimento/largura/altura diferentes do informado (±2%) | Confira as medidas digitadas ou a escala do modelo |
| triângulos acima do orçamento | Simplifique a peça (Decimate) — limites na doc 04 |
| soquete recomendado ausente (aviso) | Crie com **Criar soquete** |

## 6. Exportar
Painel **4. Exportar**: escolha a pasta — para o pacote base, `godot/content/packs/base/cars/<slug>/`; para um mod ou
para o Studio importar depois, qualquer pasta. **Exportar para o S-Senna** valida de novo e grava:
- `model.glb` — cópia da coleção com transformações aplicadas, glTF binário com +Y para cima, sem câmeras, luzes nem
  referências, e com as propriedades `ss_role`/`ss_slot`/`ss_variant` em cada objeto;
- `carkit_manifest.json` — peças, soquetes, rodas (posição e raio), materiais, triângulos e medidas, já nos eixos do
  jogo (formato na doc 03 §5.1).

### Peças universais e aros
Painel **5. Peças universais e aros**:
- **Nova peça universal**: escolha o slot (ex.: `spoiler`) e a largura de referência; modele com a origem no ponto de
  fixação e nomeie `<slot>-<nome>` (ex.: `spoiler-asa_gt`).
- **Novo aro**: cria o cilindro-guia de 18" × 8" (eixo X, face externa para +X); modele o aro dentro dele com o nome
  `rim-<nome>`. A exportação gera `rim.glb` + manifesto.

## 7. Levar para o jogo (até o Studio existir)
1. Copie o `car.json` de um carro parecido (ex.: `godot/content/packs/base/cars/prototipo/car.json`) para a pasta
   do carro e troque `id`, `display_name`, ficha e `stats`.
2. Atualize o que vem do modelo a partir do manifesto:
   ```bash
   python tools/blender/update_car_json.py godot/content/packs/base/cars/<slug>/carkit_manifest.json \
     godot/content/packs/base/cars/<slug>/car.json
   ```
   Medidas, peças, soquetes, âncoras das rodas e tamanho do pneu são reescritos; nomes/preços das peças, stats e
   `tuning_overrides` são mantidos.
3. Abra o carro:
   ```bat
   tools\scripts\showroom.bat -- --showroom-car=car:base/<slug>
   tools\scripts\campo.bat -- --campo-car=car:base/<slug>
   ```
4. Rode `tools/ci/test.sh`: o teste do pacote base confere que o modelo bate com o `car.json`.
