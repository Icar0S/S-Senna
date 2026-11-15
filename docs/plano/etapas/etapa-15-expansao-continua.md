# Etapa 15 — Expansão contínua da concessionária (e mods)

> **Marco:** contínuo (começa após o Marco B e segue para sempre) · **Depende de:** 05, 06 (e 08 para kits) · **Tamanho:** recorrente
> **Resultado:** adicionar carros da coleção vira rotina previsível; a variedade de peças e rodas cresce sem esforço proporcional.

## Objetivo
Transformar a produção de conteúdo em um processo repetível e medir o avanço da coleção dentro do jogo.

## 15.1 Fluxo por carro (rotina)
1. Escolher o próximo carro em `docs/colecao.md`.
2. Abrir issue com o formulário **"Novo carro"** (`.github/ISSUE_TEMPLATE/novo-carro.yml`): carro real, ano, miniatura (marca/escala), dimensões, links de referência, rota de modelagem (A/B/C/D da doc 04).
3. A issue gera um checklist:
   - [ ] Referências reunidas
   - [ ] Malha base
   - [ ] Peças originais separadas
   - [ ] Kits (meta: 2–3 variantes nos slots principais)
   - [ ] Materiais e soquetes
   - [ ] Validação verde no add-on
   - [ ] Importado no Studio (ficha, stats, som, preço, coleção)
   - [ ] "Versão da minha miniatura"
   - [ ] Foto da vitrine
   - [ ] Test drive aprovado
   - [ ] PR com CI verde
4. Branch `carro/<slug>`, PR, merge → o carro está na concessionária na próxima versão.

**Dica de produção**: começar com 3 carros-piloto de formatos bem diferentes (ex.: um cupê JDM, um hatch, um sedã/muscle) para
calibrar o processo antes de escalar.

## 15.2 Multiplicadores de variedade
| Item | Descrição | Prioridade |
|---|---|---|
| **Gerador procedural de aros** (no Studio) | Parâmetros: nº de raios (3–20), formato do raio (reto, curvo, duplo, malha, turbina), profundidade (*dish*), lip, furação, concavidade. Gera a malha com `SurfaceTool`, mostra prévia, exporta `.glb` + `wheel.json` normalizados. Centenas de aros novos sem modelar. | Alta — **pode ser antecipado para logo após a Etapa 09** |
| Kits universais | Crescer a biblioteca até as metas da doc 04 §5 | Alta |
| Vinis | Novas categorias (o agente consegue gerar SVGs de listras, números, formas, padrões) | Média |
| Presets de pintura | Paletas temáticas (anos 90, JDM, neon, clássicos) | Baixa |
| Looks prontos | Visuais completos de exemplo para cada carro (usados pela IA e como inspiração) | Média |

## 15.3 Acompanhamento da coleção — `docs/colecao.md`
Tabela mantida pelo dono:

| Miniatura | Marca / Escala | Carro real | Prioridade | Status |
|---|---|---|---|---|
| (ex.) RX-7 FD amarelo | Tomica · 1:64 | Mazda RX-7 FD3S 1999 | Alta | 🟨 modelando |

Status: ⬜ não iniciado · 🟦 referências · 🟨 modelando · 🟧 kits · 🟩 no jogo.
A tela **Coleção** do jogo mostra o contador "X de Y miniaturas no jogo".

## 15.4 Mods (pacotes de terceiros)
- Guia `docs/guias/criar-pacote.md`: estrutura do pacote, IDs com namespace próprio, licença obrigatória no `pack.json`, validação no Studio, exportar `.zip`.
- O jogo: Opções → Conteúdo → lista de pacotes em `user://mods` com liga/desliga e relatório de erros.
- Segurança: só JSON, `.glb`, imagens e áudio são carregados (nenhum script de mod é executado).

## 15.5 Depois da 1.0 (ideias registradas, sem compromisso)
- Mundo aberto ligando as pistas (o Centro foi pensado para crescer).
- Tráfego simples e eventos de rua.
- Polícia/perseguições (inspiração Most Wanted).
- Ciclo dia/noite e chuva dinâmica.
- Replays com câmeras de TV.
- Mais pistas: estrada de serra (touge), autódromo, porto, rodovia.
- Online via Steam Remote Play Together/Parsec (sem código) e, talvez um dia, netcode próprio.

## Critérios de aceite (por carro)
- [ ] CI verde, validação sem erros, test drive aprovado pelo dono, linha atualizada em `docs/colecao.md`.
