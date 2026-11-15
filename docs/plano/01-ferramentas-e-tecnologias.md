# 01 — Ferramentas e Tecnologias

Este documento registra **qual ferramenta usar para cada coisa, em qual versão e por quê**.
Qualquer troca de ferramenta deve virar uma nova decisão registrada na seção 4 (ADRs) antes de ser feita.

> Versões verificadas em novembro de 2026. No início da Etapa 00, o agente deve confirmar a versão estável
> mais recente nos sites oficiais e **fixar a versão exata** (não usar "a mais nova" de forma solta).

---

## 1. Tabela resumo

| Área | Ferramenta | Versão alvo | Licença | Uso no projeto |
|---|---|---|---|---|
| Motor do jogo | **Godot Engine** (build padrão, sem .NET) | 4.7.x estável (4.7.2 em nov/2026) — fixar em `.godot-version` | MIT | Jogo + Studio (mesmo projeto, dois pontos de entrada) |
| Linguagem | **GDScript com tipagem estática** | a do Godot | MIT | Todo o código do jogo e do Studio |
| Física | **Jolt Physics** (integrado ao Godot, padrão desde 4.6) | a do Godot | MIT | Corpo rígido dos carros, colisões |
| Renderização | **Forward+** (padrão) + **Compatibility** (modo leve) | a do Godot | — | Visual "PS2+" escalável |
| Modelagem 3D | **Blender** | 5.2 LTS (suporte até jul/2028) | GPL | Carros, peças, rodas, cenários |
| Add-on Blender | **S-Senna CarKit** (criado na Etapa 05, formato *Blender Extension*) | — | MIT | Organizar, validar e exportar carros |
| Formato 3D | **glTF 2.0 binário (.glb)** | — | aberto | Única ponte Blender → Godot (inclusive em tempo de execução) |
| Dados de conteúdo | **JSON** + **JSON Schema** | Draft 2020-12 | — | Carros, peças, rodas, pistas, saves |
| Texturas | **Krita** / **GIMP** | atuais | GPL | Pintura de texturas, atlas |
| Texturas procedurais | **Material Maker** (opcional) | atual | MIT | Carbono, asfalto, concreto |
| Vetores (vinis) | **Inkscape** | atual | GPL | Vinis em SVG |
| HDRIs / texturas | **Poly Haven** | — | CC0 | Iluminação da garagem e showroom |
| Ícones de botões | **Kenney Input Prompts** | — | CC0 | Ícones Xbox/PlayStation/teclado na interface |
| Fontes | **Google Fonts** | — | OFL | Fontes da interface |
| Áudio | **Audacity** | atual | GPL | Loops de motor, efeitos |
| Sons | **Freesound** (filtro CC0) + gravações próprias | — | CC0 / próprio | Motores, pneus, batidas |
| Música | Faixas CC0/CC-BY + **pasta de músicas do jogador** | — | — | Rádio do jogo |
| Testes | **gdUnit4** | v6.x (exige Godot ≥ 4.5) | MIT | Testes unitários e de cena |
| Lint/format | **gdtoolkit** (`gdlint`, `gdformat`) | 4.x | MIT | Padrão de código GDScript |
| Validação de dados | **check-jsonschema** (Python) | atual | Apache-2.0 | Validar JSONs no CI |
| Pistas (estradas) | **Godot Road Generator** (TheDuckCow) | versão compatível com 4.7 | MIT | Gerar malha de estrada a partir de curvas |
| Diálogos (opcional) | **Dialogue Manager** (Nathan Hoad) | compatível com 4.7 | MIT | Cenas de história (Etapa 13) |
| Console dev (opcional) | **LimboConsole** | compatível com 4.7 | MIT | Comandos de debug |
| Versionamento | **Git** + **Git LFS** | — | — | Código + arquivos binários |
| CI/CD | **GitHub Actions** | — | — | Lint, testes, validação, builds, releases |
| Distribuição | **GitHub Releases** (+ itch.io opcional) | — | — | Download do jogo |
| Gestão | **GitHub Issues + Projects + Milestones** | — | — | Uma milestone por Marco |
| Verificação visual (agente) | **Xvfb + Mesa (llvmpipe/lavapipe)** | — | MIT | Capturas de tela em ambiente sem GPU |

---

## 2. Detalhes e justificativas

### 2.1 Godot Engine 4.7.x — o motor
**Por quê:**
- **Leve**: editor de ~150 MB, abre em segundos; builds pequenas. Combina com o objetivo "gráficos PS2, roda em qualquer PC".
- **Licença MIT**: perfeito para repositório público, sem royalties, sem conta obrigatória.
- **Tela dividida nativa**: `SubViewport` com câmeras próprias compartilhando o mesmo mundo 3D.
- **Controles**: desde a 4.5 o suporte a gamepads no desktop usa **SDL3** (melhor compatibilidade com Xbox, DualSense, Switch Pro, genéricos).
- **Jolt Physics** integrado e padrão para projetos novos desde a 4.6 — física mais estável e rápida.
- **glTF em tempo de execução** (`GLTFDocument`): o Studio e os mods podem carregar `.glb` sem passar pelo editor. Isso é a base de "adicionar carros de forma prática".
- **Headless**: roda testes e exporta builds no CI sem tela.
- **GDScript** é simples de ler para o dono do projeto e o agente escreve bem.

**Alternativas descartadas:**
| Opção | Motivo |
|---|---|
| Unity | Editor proprietário e termos de licença que já mudaram de forma imprevisível; exige conta; C# obrigatório. |
| Unreal Engine 5 | Pesado (editor e builds enormes), contra o pilar "leve"; C++/Blueprints difíceis de revisar em PR. |
| Bevy (Rust) / motor próprio | Sem editor visual maduro; atrasaria o pipeline de conteúdo, que é o foco. |
| Web (Three.js) | Física, desempenho e pipeline de conteúdo inferiores para este tipo de jogo. |

**Regra de versão:** fixar a versão exata em `/.godot-version` (ex.: `4.7.2`). Atualizações de patch (4.7.x) são livres;
atualizar de versão menor (4.7 → 4.8) exige um PR próprio com ADR, testes verdes e playtest.

### 2.2 GDScript tipado
- Tipagem estática **obrigatória**: o projeto configura o aviso `untyped_declaration` como **erro**.
- Melhor desempenho (o Godot otimiza código tipado) e menos bugs.
- **Sem C#**: evitaria a dependência do .NET, complicaria as exportações e o setup de quem quer rodar do código-fonte.
- Se algum trecho virar gargalo comprovado no *profiler*, primeiro otimizar o algoritmo; GDExtension (C++) só como último recurso e com ADR.

### 2.3 Física: Jolt + veículo próprio por raycast
- **Não usar `VehicleBody3D`**: ele é pensado para simulação e dá pouco controle sobre aderência e drift; o comportamento arcade que queremos (fácil, estável, divertido) exige controle total.
- Padrão adotado: `RigidBody3D` para o chassi + 4 "rodas" virtuais por `RayCast3D` (ou `ShapeCast3D` esférico) que aplicam forças de suspensão, tração e aderência. É o padrão usado em jogos de corrida arcade.
- Física a **120 Hz** com **interpolação de física** ligada (estável e suave em qualquer taxa de quadros).

### 2.4 Renderização: Forward+ com modo "leve"
- **Forward+** (Vulkan/D3D12) como padrão: muitas luzes (cidade à noite), decals (neon no chão), reflexos (SSR opcional), glow.
- **Compatibility** (OpenGL 3.3) como **modo leve** para PCs fracos, ativado por parâmetro de linha de comando
  (`--rendering-method gl_compatibility`) e por um atalho `S-Senna (modo leve)` no zip do jogo.
- Regra: todos os shaders do projeto devem compilar e ficar aceitáveis nos dois modos. Efeitos exclusivos do Forward+ (SSR, por exemplo) são opcionais e desligáveis.
- O modo Compatibility também permite que o agente tire **capturas de tela em ambiente sem GPU** (Xvfb + Mesa), para conferir o próprio trabalho.

### 2.5 Blender 5.2 LTS + add-on S-Senna CarKit
- Blender é gratuito, padrão da indústria indie e exporta glTF muito bem.
- Usar a versão **LTS** para que o add-on não quebre a cada atualização.
- O add-on (Etapa 05) transforma o trabalho repetitivo em botões: criar estrutura do carro, posicionar planos de referência com as **dimensões reais**, separar peças, nomear, marcar materiais, criar soquetes, detectar rodas, validar e exportar.
- Formato *Blender Extension* (`blender_manifest.toml`), instalável arrastando o `.zip` para o Blender.

### 2.6 glTF 2.0 (.glb) como único formato 3D
- Godot importa `.glb` no editor (com LODs automáticos e compressão) **e** carrega em tempo de execução (`GLTFDocument`) — o que permite o Studio exportado e os mods.
- **Proibido** usar `.fbx`, `.obj` ou `.blend` direto no projeto Godot. Os `.blend` ficam em `source_assets/` (fora do projeto).
- Propriedades personalizadas do Blender viram `extras` no glTF e chegam ao Godot como *metadata* — usado para identificar peças (ver `03-formatos-de-dados.md` e `04-padroes-de-arte-e-pipeline-de-carros.md`). A Etapa 01 deve ter um teste que confirma esse comportamento na versão fixada do Godot; se falhar, cair para identificação só por nome.

### 2.7 JSON + JSON Schema para conteúdo (em vez de `.tres`)
- **Seguro para mods**: um `.tres`/`.tscn` carregado de fora pode conter scripts; JSON não executa nada.
- **Editável fora do Godot**: o Studio, o add-on do Blender (Python) e o CI (Python) leem e escrevem JSON facilmente.
- **Diffs legíveis** nos PRs e **validação automática** por JSON Schema no CI.
- Dentro do jogo, cada JSON é convertido para uma classe tipada (`CarDef`, `PartDef`…) com validação e mensagens de erro claras.

### 2.8 Testes e qualidade
- **gdUnit4 v6.x**: testes unitários, testes de cena e simulação de entrada; tem runner de linha de comando e GitHub Action oficial (`MikeSchulze/gdUnit4-action`). Confirmar na Etapa 00 que a versão escolhida suporta Godot 4.7.
- **gdtoolkit**: `gdformat --check` e `gdlint` no CI.
- **check-jsonschema**: valida todos os JSONs de conteúdo contra `schemas/`.
- **Testes de física headless**: a física roda no modo `--headless`, então dá para testar automaticamente "o carro chega a 100 km/h em X segundos", "a IA completa a volta sem travar" etc.

### 2.9 Git LFS e distribuição
- Arquivos binários (`.glb`, `.blend`, `.png`, `.jpg`, `.ogg`, `.wav`, `.ttf`…) vão para o **Git LFS**.
- Cota gratuita do GitHub (nov/2026): **10 GiB de armazenamento e 10 GiB de banda por mês**. Downloads de CI e de forks contam na banda.
  - Por isso: os testes do CI usam **fixtures pequenas fora do LFS** (geradas por script); só o workflow de release baixa os arquivos LFS, com cache.
- Os **jogadores baixam o jogo pelo GitHub Releases** (não conta na cota do LFS) — o README manda direto para lá.

### 2.10 Godot Road Generator (pistas)
- Plugin MIT que gera malhas de estrada a partir de pontos/curvas (faixas, acostamento, calçada). Acelera muito a criação das pistas.
- Prédios, postes e props: kit modular feito no Blender, montado no Godot com `MultiMeshInstance3D` para itens repetidos.

### 2.11 Áudio
- Motor: sistema de **loops com crossfade por RPM** (marcha lenta, baixa, média, alta, com e sem carga) — é o que dá vida ao carro com pouco custo.
- Fontes: Freesound (somente CC0), sons gravados pelo próprio dono (encontros de carros, por exemplo) e efeitos gerados.
- **Rádio**: o jogo toca músicas incluídas (CC0/CC-BY, com créditos) **e** arquivos OGG/MP3 de uma pasta do jogador — assim cada um monta a própria trilha "estilo Underground" sem problemas de licença no repositório.

### 2.12 Ferramentas opcionais para acelerar a modelagem dos carros
| Ferramenta | Tipo | Quando ajuda | Cuidado |
|---|---|---|---|
| Blueprints (vistas lateral/frontal/traseira/superior) | Referência | Sempre — base da modelagem | Usar só como referência, não redistribuir as imagens no repo |
| Fotos das próprias miniaturas | Referência | Detalhes, cores, pintura "de fábrica" da miniatura | Fotografar com zoom (pouca distorção) e uma régua junto |
| Image-to-3D por IA (ex.: TRELLIS — MIT; Hunyuan3D — licença com restrições regionais; serviços pagos como Meshy/Tripo) | Malha base | Ter rapidamente a forma geral do carro | Topologia ruim, peças fundidas: sempre retopologizar/limpar no Blender; conferir a licença do resultado |
| Fotogrametria (RealityScan, Meshroom) | Malha base | Miniaturas grandes (1:18, 1:24) | Pintura metálica brilhante atrapalha; sprays foscos temporários podem danificar colecionáveis — evitar em peças de valor |
| Modelos de terceiros (Sketchfab etc.) | Malha pronta | Só com licença explícita que permita uso e redistribuição (CC0/CC-BY) e feitos pelo próprio autor | **Nunca** usar modelos "extraídos" de outros jogos (são ilegais, mesmo se gratuitos) |

### 2.13 Verificação visual pelo agente
O agente (Fable 5.2) não "joga" o jogo, mas pode **ver** o resultado:
- Script `tools/scripts/screenshot.sh <cena> <saida.png>` roda a cena com `xvfb-run` + renderização por software (Mesa) no modo Compatibility, espera N quadros e salva a imagem.
- Usar em todas as etapas visuais para conferir pintura, peças, interface e tela dividida antes de abrir o PR.
- Pacotes de sistema necessários no ambiente (Debian/Ubuntu): `xvfb`, `libgl1-mesa-dri`, `mesa-vulkan-drivers` (opcional).

---

## 3. Endereços oficiais (para o agente confirmar versões)
- Godot: https://godotengine.org/download — builds oficiais e templates: https://github.com/godotengine/godot-builds/releases
- Blender: https://www.blender.org/download/lts/
- gdUnit4: https://github.com/MikeSchulze/gdUnit4 — Action: https://github.com/MikeSchulze/gdUnit4-action
- gdtoolkit: https://github.com/Scony/godot-gdscript-toolkit
- Godot Road Generator: https://github.com/TheDuckCow/godot-road-generator
- Poly Haven: https://polyhaven.com — Kenney: https://kenney.nl/assets/input-prompts
- check-jsonschema: https://github.com/python-jsonschema/check-jsonschema

---

## 4. Registro de decisões (ADRs)

Cada decisão importante fica registrada aqui. Para mudar uma, adicione uma nova ADR que "substitui" a anterior.

| ADR | Decisão | Motivo principal |
|---|---|---|
| 001 | Godot 4.7.x como motor | Leve, MIT, split-screen e glTF em runtime nativos |
| 002 | GDScript tipado, sem C# | Simplicidade de setup e exportação; legibilidade |
| 003 | Conteúdo em JSON + JSON Schema | Seguro para mods, editável por Studio/Blender/CI |
| 004 | **Um único projeto Godot com dois pontos de entrada** (Jogo e Studio) | O Studio reaproveita 100% do código de montagem/renderização/física do jogo — o que se vê no Studio é exatamente o que aparece no jogo |
| 005 | Veículo próprio por raycast sobre `RigidBody3D` (Jolt) | Controle total da sensação arcade |
| 006 | **Materiais identificados pelo nome** (`paint_body`, `chrome`, `glass`…) e substituídos pelos materiais do jogo | O modelador não precisa configurar shaders; o jogo controla pintura e acabamento |
| 007 | **Vinis desenhados em telas 2D por lado do carro** e aplicados por projeção no shader | Não exige UV especial no modelo; editor intuitivo; custo constante em tempo de jogo |
| 008 | Save em JSON com escrita atômica, 3 backups e migrações versionadas | Nunca perder o progresso do jogador |
| 009 | Git LFS para binários; jogadores baixam pelo GitHub Releases | Repo leve para clonar; download do jogo sem gastar cota |
| 010 | Garagem única (estilo Midnight Club) em vez de lojas separadas | Mais prático para o jogador |
| 011 | Arquitetura multi-jogador desde a Etapa 04 (nada de câmera/HUD globais) | Tela dividida é pilar, não extra |
