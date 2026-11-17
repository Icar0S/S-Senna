# Contribuindo com o S-Senna

Obrigado pelo interesse! Este documento resume como o projeto é organizado e o que conferir antes de enviar mudanças.
O plano completo está em [`docs/plano/`](docs/plano/README.md).

## Preparar o ambiente
Veja o guia [`docs/guias/ambiente-de-desenvolvimento.md`](docs/guias/ambiente-de-desenvolvimento.md):
Godot na versão do arquivo `.godot-version`, Git LFS e, para contribuir com código, o `gdtoolkit`.

## Fluxo de trabalho

O repositório tem **duas branches**:

| Branch | Para quê |
|---|---|
| `dev` | Onde o desenvolvimento acontece. As etapas do plano avançam aqui, em commits pequenos. |
| `main` | Versão estável. Recebe o merge de `dev` **quando uma etapa é concluída** e o CI está verde. |

- **Dono/agente**: trabalha direto em `dev`; ao concluir a etapa (critérios 🤖 verdes), faz o merge em `main`.
- **Colaboradores externos**: faça um fork, crie um branch a partir de `dev` e abra um pull request **para `dev`**.
- Uma etapa por vez, na ordem do [roteiro](docs/plano/README.md). Etapas grandes podem ser entregues em partes
  (`08a`, `08b`…), cada parte com seus testes.
- Mensagens de commit em português, no formato `tipo(escopo): resumo` — por exemplo
  `feat(etapa-01): ContentId valida IDs de conteúdo` ou `docs(plano): ajusta etapa 03`.
  Tipos usados: `feat`, `fix`, `docs`, `test`, `chore`, `refactor`, `ci`.

## Antes de enviar

```bash
tools/ci/lint.sh                 # gdformat --check + gdlint
tools/ci/test.sh                 # testes gdUnit4 headless
tools/ci/validate_content.sh     # JSON do conteúdo
tools/ci/check_architecture.sh   # regras de dependência
```

- Tudo verde localmente e no CI (GitHub Actions).
- Etapas visuais: anexe capturas de tela (`tools/scripts/screenshot.sh`).
- Atualize `CHANGELOG.md`, `docs/plano/PROGRESSO.md` e os guias em `docs/guias/` quando a mudança pedir.
- Critérios de aceite da etapa: os 🤖 conferidos; os 🎮 listados para o dono testar.

## Convenções de código
Resumo de [`docs/plano/02-arquitetura.md`](docs/plano/02-arquitetura.md) §7:

- Código em **inglês**; documentação e textos de interface em **pt-BR** (interface sempre por chaves de tradução).
- GDScript **100% tipado** (o aviso `untyped_declaration` é erro no projeto).
- Lógica em classes `RefCounted` testáveis; nós finos, que só ligam a lógica à cena.
- Arquivos `snake_case.gd`/`.tscn`; classes `PascalCase`; constantes `UPPER_SNAKE_CASE`; sinais com verbo no passado.
- `godot/core/` não depende de `game/`, `studio/` nem de `GameSession`.
- Slots, materiais e soquetes vêm de `godot/core/content/conventions.json` — sem strings mágicas.
- Código de jogador nunca usa `Input.is_action_pressed` direto: sempre pelo `InputRouter` (multi-jogador).
- Tudo que puder rodar no modo Compatibility deve rodar (shaders inclusos).
- Testes junto do código: `godot/tests/unit/` e `godot/tests/integration/`.

## Conteúdo e saves
- Conteúdo em JSON conforme [`docs/plano/03-formatos-de-dados.md`](docs/plano/03-formatos-de-dados.md), com schema em `schemas/`.
  Mudou o formato? Atualize o documento, o schema e a migração juntos.
- **Nunca** reutilize ou apague IDs de conteúdo já publicados: use `aliases`.
- **Nunca** quebre saves: toda mudança de formato tem migração e teste com *golden file*.

## Arquivos binários (Git LFS)
Modelos, texturas, áudio e fontes vão para o Git LFS (regras no `.gitattributes`). Exceções, que ficam no Git comum
porque o CI faz checkout sem LFS: `godot/tests/fixtures/` e `godot/addons/`.

Atenção no Godot 4: os arquivos **`*.import` e `*.uid` devem ser commitados**; a pasta `godot/.godot/` não.

## Assets de terceiros e questões legais
- Nenhum asset de terceiros entra sem licença compatível registrada em [`CREDITS.md`](CREDITS.md).
- **Proibido**: modelos extraídos de outros jogos, logos reais e músicas comerciais.
- Código: licença MIT ([`LICENSE`](LICENSE)). Arte e áudio: ver [`LICENSE-ASSETS.md`](LICENSE-ASSETS.md).
- Ao contribuir, você concorda em licenciar sua contribuição nesses mesmos termos.

## Bugs e ideias
Use os formulários em **Issues** (`Bug` e `Ideia`). Para bugs, anexe o arquivo de log
(`%APPDATA%\S-Senna\logs\s-senna.log` no Windows, `~/.local/share/S-Senna/logs/s-senna.log` no Linux).
