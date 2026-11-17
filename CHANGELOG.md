# Changelog

Todas as mudanças relevantes do S-Senna são registradas aqui.
O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto usa
[Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

### Adicionado
- **Etapa 00 — Fundação**
  - Projeto Godot 4.7.2 em `godot/` (Forward+, Jolt, física a 120 Hz com interpolação, tipagem obrigatória).
  - Cena de boot que abre o **Jogo** ou o **S-Senna Studio** (`--studio` ou feature `studio`).
  - Telas provisórias do Jogo (título + versão) e do Studio.
  - Autoload `Log` com níveis e arquivo em `user://logs/s-senna.log` (rotação de 5 arquivos).
  - 4 presets de exportação (Jogo/Studio × Windows/Linux) e `tools/ci/export.sh`, que confere o conteúdo das builds.
  - gdUnit4 6.2.3 para testes; scripts `tools/ci/` de lint, testes, validação de conteúdo e arquitetura.
  - CI no GitHub Actions (lint, testes, arquitetura, conteúdo, exportação e captura de tela).
  - Scripts `jogar` e `studio` (`.sh`/`.bat`) e captura de tela (`tools/scripts/screenshot.sh`).
  - Licenças (`LICENSE`, `LICENSE-ASSETS.md`), `CREDITS.md`, `CONTRIBUTING.md` e modelos de issue.
  - Guia [`docs/guias/ambiente-de-desenvolvimento.md`](docs/guias/ambiente-de-desenvolvimento.md).

### Alterado
- Fluxo de branches: o desenvolvimento acontece em `dev` e vai para `main` ao concluir cada etapa
  (antes: um branch por etapa).
