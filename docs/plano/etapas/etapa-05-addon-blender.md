# Etapa 05 — Pipeline no Blender (add-on "S-Senna CarKit")

> **Marco:** B · **Depende de:** 01, 03 · **Tamanho:** G
> **Resultado:** com o add-on, preparar um carro no Blender vira uma sequência de botões, e o arquivo exportado entra no jogo sem ajustes manuais.

## Objetivo
Transformar o trabalho repetitivo e propenso a erro (nomes, escala, eixos, materiais, soquetes, rodas, exportação) em
ferramentas guiadas, para que o dono gaste o tempo **só com a forma do carro**.

## Entregáveis
- `tools/blender/senna_carkit/` no formato **Blender Extension** (`blender_manifest.toml`), alvo **Blender 5.2 LTS**.
- Painel "S-Senna" na barra lateral (N) da Viewport 3D.
- Validador e exportador.
- `tools/blender/build_extension.sh` → gera o `.zip` instalável (copiando `conventions.json` do projeto Godot para dentro do add-on).
- Testes headless (`blender -b --factory-startup -P tools/blender/tests/run_tests.py`).
- Guia `docs/guias/adicionar-carro.md` (parte do Blender) e `docs/guias/instalar-addon-blender.md`.
- Carro protótipo v2 produzido de ponta a ponta pelo add-on.

## Funcionalidades do painel (em passos, de cima para baixo)

### 1. Novo carro
- Campos: nome/slug, comprimento, largura, altura, entre-eixos (mm).
- Escolher imagens de referência (frente, lateral, traseira, topo): o add-on cria **planos de referência na escala real**, centralizados, semitransparentes e não selecionáveis.
- Cria a **caixa-guia** das dimensões, a coleção `carro-<slug>` com subcoleções (`peças`, `soquetes`, `rodas`, `referências`) e grava as dimensões como propriedades da cena.

### 2. Ferramentas de modelagem/organização
| Botão | O que faz |
|---|---|
| Ajustar escala pelo comprimento real | escala a malha selecionada para o comprimento informado |
| Separar como peça | separa as faces selecionadas em um objeto `<slot>-stock` (escolhe o slot numa lista) |
| Criar variante | duplica a peça ativa como `<slot>-kitNN` (próximo número livre) e esconde a original |
| Material do jogo | atribui às faces selecionadas um material oficial (lista de `conventions.json`), criando-o se não existir, com cor de pré-visualização |
| Criar soquete | cria `socket-<nome>` no cursor 3D, com orientação correta e propriedades (`width_m` etc.) |
| Espelhar L→R | cria/atualiza o par direito de soquetes/peças `_L` |
| Detectar rodas | a partir das malhas de roda selecionadas, calcula centro e raio, cria `wheel-FL/FR/RL/RR`, opcionalmente transforma uma delas em `rim-stock` normalizado e esconde as originais |
| Pré-visualizar tamanho de aro | mostra um cilindro fantasma do aro máximo para conferir o para-lama |

### 3. Validar
Lista de problemas com ícone (vermelho = bloqueia, amarelo = aviso) e botão "selecionar" em cada item:
escala não aplicada, frente fora de −Y, rodas fora de Z = 0, dimensões ±2% diferentes do informado, nomes inválidos ou com `.001`,
sufixos de importação do Godot, materiais fora da lista, faces sem material, slots sem variante `stock`, rodas assimétricas (> 1 cm),
orçamento de triângulos estourado (por objeto e total), soquetes obrigatórios ausentes (aviso).

### 4. Exportar para o S-Senna
- Escolher a pasta do pacote (ex.: `godot/content/packs/base/cars/<slug>/` ou uma pasta qualquer para o Studio importar).
- Exporta **cópia** da coleção com transformações aplicadas, triangulada, glTF binário, +Y para cima, com propriedades personalizadas (`extras`), sem câmeras/luzes/referências.
- Grava as propriedades `ss_role`, `ss_slot`, `ss_variant` em cada objeto antes de exportar.
- Gera `carkit_manifest.json`: slug, dimensões, peças, soquetes, rodas (posição e raio), materiais, contagem de triângulos, versão do add-on.
- Não exporta se houver erro vermelho.

### 5. Modelos para peças universais e aros
- "Nova peça universal" (slot + largura de referência) e "Novo aro" (cilindro-guia 18" × 8", eixo X, face +X) com exportação própria e manifesto.

## Tarefas
1. Esqueleto da extensão (manifest, registro, painel, preferências com caminho padrão do pacote).
2. Ler `conventions.json` embutido (fonte única com o Godot).
3. Implementar operadores das seções 1–5, cada um com *undo* do Blender.
4. Validador como módulo Python puro (testável sem UI).
5. Exportador com as opções exatas do glTF e o manifesto.
6. Testes headless: criar cena sintética via `bpy`, rodar validação (casos bons e ruins), exportar, conferir manifesto e abrir o `.glb` no Godot (`ConventionScanner`) num teste de integração.
7. CI: job opcional `blender` que só roda quando `tools/blender/**` muda (baixa Blender 5.2 LTS com cache).
8. Produzir o **protótipo v2** (carro low-poly mais bonito, feito via script `bpy` + operadores do add-on) e substituí-lo no pacote base.
9. Escrever os guias.

## Critérios de aceite
### 🤖 Automáticos
- [ ] Testes do validador: cada regra tem um caso que passa e um que falha.
- [ ] Exportação do protótipo → Godot monta o carro **sem nenhum aviso** (`CarAssembler`).
- [ ] Manifesto bate com o que o `ConventionScanner` encontra.
### 🎮 Manuais (dono)
- [ ] Instalar o add-on arrastando o `.zip` no Blender 5.2.
- [ ] Seguir o guia com um modelo simples (pode ser um carro baixado com licença livre) e chegar ao `.glb` validado.

## Armadilhas
- Exportar o objeto original em vez de uma cópia (estraga o `.blend` do usuário): sempre trabalhar numa cópia temporária.
- API do Blender muda entre versões: fixar 5.2 LTS no manifesto (`blender_version_min`).

## Fora do escopo
Ficha do carro, stats, sons, preço (tudo isso é no Studio, Etapa 06).
