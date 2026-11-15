# Etapa 06 — S-Senna Studio (a "engine" separada para criar conteúdo)

> **Marco:** B · **Depende de:** 01, 03, 04, 05 · **Tamanho:** G
> **Resultado:** o dono importa o `.glb` de um carro da coleção, preenche uma ficha, faz test drive e o carro entra na Concessionária — **sem editar JSON à mão**.

## Objetivo
Um aplicativo separado do jogo (mas do mesmo projeto Godot, ADR 004) para **adicionar e editar** carros, peças universais,
rodas e vinis. Ele roda de duas formas:

| Forma | Como abrir | Onde grava |
|---|---|---|
| Do código-fonte | `tools/scripts/studio.bat` / `godot --path godot -- --studio` | direto em `godot/content/packs/<pacote>/` (pronto para commit) |
| Executável exportado | `S-Senna Studio.exe` | `user://mods/<pacote>/` **ou** uma pasta escolhida com `--content-dir=<repo>/godot/content` |

## Entregáveis
- `studio/` completo: `studio_main.tscn` e módulos abaixo.
- Componente de formulário genérico (`studio/ui/json_form.gd`) que monta campos a partir de uma especificação (tipo, faixa, lista de opções, ajuda) — evita escrever uma tela para cada tipo de dado.
- Guia `docs/guias/studio.md` e a segunda metade de `docs/guias/adicionar-carro.md`.
- **O primeiro carro real da coleção** adicionado pelo dono como teste de aceite.

## Layout
```
┌────────────────────────────────────────────────────────────────────────────┐
│ Pacote: [base ▼]  [Novo carro] [Nova peça] [Nova roda] [Vinis] [Validar tudo] │
├──────────────┬───────────────────────────────────────┬────────────────────────┤
│ Navegador    │  Pré-visualização 3D (CarAssembler)   │  Inspetor (formulário) │
│ ▸ Carros     │  - orbitar / zoom                     │  - Ficha               │
│ ▸ Peças univ.│  - iluminação: garagem / dia / noite  │  - Stats (+ presets)   │
│ ▸ Rodas      │  - alternar peças / rodas / pintura   │  - Som                 │
│ ▸ Vinis      │                                       │  - Economia            │
│              │                                       │  - Coleção             │
├──────────────┴───────────────────────────────────────┴────────────────────────┤
│ Validação: ✔ 0 erros  ⚠ 2 avisos (clique para ver)       [Test drive] [Salvar]  │
└────────────────────────────────────────────────────────────────────────────┘
```

## Funcionalidades
### 6.1 Assistente "Novo carro"
1. Escolher o `.glb` (diálogo nativo do sistema) — aceita o `carkit_manifest.json` ao lado, se existir.
2. O Studio **copia** os arquivos para a pasta do pacote (nunca referencia arquivos fora dele).
3. `ConventionScanner` mostra o que encontrou: peças por slot, soquetes, rodas, materiais, triângulos. Itens não reconhecidos podem ser **atribuídos manualmente** num menu (ex.: "este objeto é o `hood-kit01`") — o Studio renomeia/grava a metadata.
4. Ficha: nome, fabricante, ano, país, categoria, dimensões (pré-preenchidas pelo manifesto).
5. **Stats por preset**: escolher "JDM esportivo anos 90", "Muscle V8", "Hot hatch", "Supercarro", "Clássico", "Popular"… e ajustar com sliders; barras de comparação com outro carro do pacote.
6. **Som**: escolher perfil de motor (I4, I6, V6, V8, V10, V12, Boxer, Rotativo) e ouvir a prévia variando o RPM.
7. **Rodas**: conferir âncoras, raio do pneu, aro original; ferramenta de **encaixe** (mostra o maior aro/tala permitido; ajustar `rim_in_max`, `width_in_max`, `max_offset_mm`, `max_camber_deg`).
8. **Pintura padrão** e zonas; **"Versão da minha miniatura"** (pintura simples agora; vinis quando a Etapa 08 existir).
9. **Economia**: preço sugerido calculado pelo desempenho (editável), desbloqueio.
10. **Coleção**: marca da miniatura, escala, data, foto (copiada para a pasta), observações.
11. **Peças**: nome, preço, pontos de estilo e acabamentos permitidos de cada variante.
12. **Foto da vitrine** automática (`ThumbnailRenderer`: `SubViewport` com fundo transparente, ângulo 3/4 padronizado, iluminação de estúdio, 512×288 PNG).
13. **Test drive**: abre o Campo Plano com o carro (mesma cena da Etapa 04, com F1/F2) e volta para o Studio ao apertar Esc. Ajustes do F2 podem ser salvos como `tuning_overrides` deste carro.
14. **Salvar**: grava `car.json` (formato da doc 03), valida, chama `ContentDB.rescan()`.

### 6.2 Peças universais, rodas e vinis
- **Nova peça universal**: importar `.glb`, escolher slot, largura de referência, regras (`hides/requires/conflicts`), acabamentos, preço; pré-visualizar em qualquer carro do pacote (ajustando ao soquete).
- **Nova roda**: importar aro, conferir normalização (18" × 8", eixo X), zonas de pintura, faixa de tamanhos; pré-visualizar em vários carros.
- **Vinis**: importar SVG/PNG para uma categoria, definir número de cores, preço; grade de miniaturas.

### 6.3 Validação e pacotes
- "Validar tudo": roda o validador sobre todo o pacote (os mesmos testes do CI) e lista problemas clicáveis.
- **Exportar pacote como .zip** (para compartilhar mods) e **Instalar pacote .zip** em `user://mods`.
- Desfazer/refazer nas edições de formulário (`UndoRedo`).

## Tarefas
1. Estrutura do Studio e navegação; tema próprio (sóbrio, diferente do jogo).
2. `json_form.gd` + especificações de campos para car/part/wheel/vinyl.
3. `ContentWriter`: grava JSON formatado (chaves ordenadas, 2 espaços) para diffs limpos; nunca apaga arquivos sem confirmação.
4. Assistente de novo carro (6.1), editores de peças/rodas/vinis (6.2), validação e pacotes (6.3).
5. `ThumbnailRenderer` (também usado por um comando "regerar todas as fotos").
6. `TestDriveLauncher` (entrar e voltar da cena de física preservando o estado do Studio).
7. Diálogos de arquivo nativos (`FileDialog` com `use_native_dialog`).
8. Guias com capturas de tela (geradas pelo `screenshot.sh`).

## Critérios de aceite
### 🤖 Automáticos
- [ ] Teste de integração: importar a fixture pelo `ContentWriter` em pasta temporária → `car.json` válido no schema → `ContentDB` carrega → `CarAssembler` monta sem avisos.
- [ ] JSON gerado é estável (salvar duas vezes sem mudanças = arquivo idêntico).
- [ ] Studio exportado grava em `user://mods/` e o Jogo exportado lê esse mod.
- [ ] Zip exportado e reinstalado reproduz o pacote.
### 🎮 Manuais (dono)
- [ ] **Adicionar o primeiro carro real da coleção**: do `.glb` validado até ele aparecer na lista de carros do jogo, em menos de 30 minutos, sem abrir nenhum JSON.
- [ ] Fazer test drive e salvar um ajuste de direção para esse carro.

## Fora do escopo
Gerador procedural de aros (Etapa 15). Edição de pistas e carreira (feitas no editor do Godot e em JSON, Etapas 11 e 13).
