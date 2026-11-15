# 05 — Riscos e Questões Legais

## 1. Riscos do projeto

| # | Risco | Impacto | Probabilidade | Mitigação |
|---|---|---|---|---|
| R1 | **Produção de carros é lenta** (o gargalo real do projeto) | Alto | Alta | Add-on + Studio (Etapas 05–06); 4 rotas de malha (doc 04 §3); peças universais servem para todos; gerador de aros; meta de 3 carros-piloto antes de escalar |
| R2 | **Sensação de direção não fica boa** | Alto | Média | `HandlingModel` centralizado e testado; painel F2 para o dono ajustar sem código; playtest obrigatório na Etapa 04 |
| R3 | **Desempenho em tela dividida** | Alto | Média | Orçamentos de polígonos/draw calls; preset automático para tela dividida; benchmark com linha de base; modo leve (Compatibility) |
| R4 | **Escopo cresce demais** (mundo aberto, polícia…) | Alto | Alta | Lista "fora do escopo" (doc 00 §5.2); ideias vão para Etapa 15 §15.5, não para a etapa atual |
| R5 | Agente não consegue "sentir" o jogo | Médio | Certa | Testes de física headless com faixas esperadas; capturas de tela; critérios 🎮 marcados para o dono em todo PR |
| R6 | Cota do Git LFS estourar | Médio | Média | CI sem LFS (fixtures fora do LFS); jogadores baixam pelo Releases; texturas ≤ 2048²; `.blend` grandes podem ficar fora do repo se necessário |
| R7 | Saves quebrarem entre versões | Alto | Média | `schema_version` + migrações com golden files; IDs nunca reutilizados; aliases |
| R8 | Atualização do Godot quebrar algo | Médio | Baixa | Versão fixada; troca de versão menor só com ADR + testes + playtest |
| R9 | Controles problemáticos (Steam Input, genéricos) | Médio | Média | SDL3 do Godot; tela de teste de controles; seção no README |
| R10 | Vinis com distorção na projeção | Baixo | Média | Máscara pela normal; aceitar como estilo; limites de posicionamento |
| R11 | Mods com conteúdo quebrado | Baixo | Média | Validação robusta; conteúdo ruim nunca derruba o jogo (usa original) |

## 2. Questões legais (⚠️ não é aconselhamento jurídico)

Este é um projeto **gratuito, não comercial e público**. Mesmo assim, vale conhecer os pontos de atenção:

### 2.1 Carros reais (marcas, nomes e formas)
- Nomes de fabricantes/modelos, logotipos e o design dos carros podem ser protegidos por marcas registradas e direitos de design. Jogos comerciais pagam licenças para usá-los.
- Para reduzir riscos no repositório público:
  - **Sem logotipos e emblemas reais** nos modelos e texturas (usar emblemas genéricos ou nenhum).
  - Nomes reais ficam **só nos dados** (`display_name`, `manufacturer`), fáceis de trocar. Se um dia for necessário, uma opção de build pode exibir nomes alternativos/fictícios sem mudar os modelos.
  - Marcas de peças, rodas e "patrocinadores" são **sempre fictícias**.
- 🧑 Decisão do dono: manter nomes reais nos dados (padrão deste plano) ou usar nomes fictícios desde o início.

### 2.2 Nome do jogo
- "Senna" é um nome associado a marcas registradas (por exemplo, ligadas à família/instituto de Ayrton Senna e ao modelo McLaren Senna). Para um projeto pessoal e gratuito o risco é baixo, mas, se o jogo ganhar visibilidade, vale considerar um nome final distinto. 🧑 Decisão do dono antes da 1.0.

### 2.3 Assets de terceiros
- Só aceitar assets com licença explícita que permita **uso e redistribuição** (CC0, CC-BY, OFL, MIT…), sempre registrados em `CREDITS.md` com autor, link e licença.
- **Proibido**: modelos/sons/texturas extraídos de outros jogos, músicas comerciais, imagens sem licença (inclusive blueprints — usar só como referência local, sem commitar).
- Conteúdo gerado por IA: conferir os termos da ferramenta usada e registrar a origem em `credits` no JSON do carro.

### 2.4 Licenças do próprio projeto
- **Código**: MIT (permite que qualquer um use e modifique).
- **Arte e áudio originais**: 🧑 decisão do dono em `LICENSE-ASSETS.md`. Sugestão: **CC BY-NC-SA 4.0** (permite compartilhar e adaptar com crédito, sem uso comercial, mantendo a mesma licença) — combina com um projeto de fãs que envolve carros reais.

### 2.5 Músicas
- O jogo não inclui músicas comerciais. O rádio toca a pasta do próprio jogador (arquivos que ele já tem), e o repositório só leva faixas CC0/CC-BY.

## 3. Decisões pendentes do dono (resumo)
| # | Decisão | Padrão adotado pelo plano até decidir | Quando |
|---|---|---|---|
| D1 | Nome final do jogo | "S-Senna" | antes da Etapa 14 |
| D2 | Licença dos assets | CC BY-NC-SA 4.0 | Etapa 00 |
| D3 | Nomes reais vs. fictícios dos carros | reais nos dados, sem logos | Etapa 06 |
| D4 | Cenário/cidade e personagens da história | metrópole brasileira fictícia | Etapa 13 |
| D5 | Ordem dos carros da coleção | definida em `docs/colecao.md` | Etapa 06 |
| D6 | Inglês além do português | sim (chaves de tradução desde o início; textos em inglês podem vir depois) | Etapa 09 |
| D7 | Publicar também no itch.io | não | Etapa 14 |
