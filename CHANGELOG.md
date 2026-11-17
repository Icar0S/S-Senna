# Changelog

Todas as mudanças relevantes do S-Senna são registradas aqui.
O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto usa
[Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

### Adicionado
- **Etapa 02 — Sistema de save**
  - Perfis salvos com segurança: gravação atômica, 3 backups automáticos e checksum; se o arquivo principal
    estragar, o jogo recupera do backup e avisa.
  - Perfis: criar, carregar, excluir (vai para a lixeira), duplicar, exportar e importar em `.zip`.
  - Autosave agrupado (vários pedidos em ~1 s viram uma gravação) e salvamento ao fechar o jogo.
  - Customização completa de cada carro guardada no perfil; peças de mods desativados nunca somem do save.
  - Saves de uma versão mais nova do jogo abrem só para leitura e nunca são sobrescritos.
  - Migração de saves entre versões (mecanismo + modelo testado com um save real).
  - Configurações (`settings.json`) e controles (`input.json`), com valores padrão na primeira execução.
  - **Modo portátil**: um `portable.txt` ao lado do executável guarda tudo em `save/` na pasta do jogo.
  - Traduções pt-BR e inglês (`godot/ui/i18n/strings.csv`).
  - Tela de teste de perfis: `res://game/sandbox/save_debug.tscn`.
- **Etapa 01 — Núcleo de conteúdo**
  - `ContentDB` (autoload) e `ContentLibrary`: descobrem pacotes (oficiais, mods habilitados e `--content-dir`),
    ordenam por dependências e prioridade, aplicam aliases e respondem consultas (`get_car`, `list_parts_for`…).
  - Definições tipadas com validação e relatório em português: carro, peça, roda, vinil, pintura, pista,
    som do motor, upgrades e economia (`economy.json` ganhou formato próprio).
  - `ModelLoader` (modelos importados ou externos, com cache) e `ConventionScanner` (lê peças, soquetes,
    rodas e materiais de um `.glb` pela metadata ou pelo nome).
  - JSON Schemas em `schemas/`; a validação de conteúdo passa a usar o `check-jsonschema`.
  - Gerador `tools/fixtures/make_test_car.sh`: carro de teste e conteúdo inicial do pacote `base`
    (Protótipo S-Senna, aros Básica 5 e Disco Aero, Asa Simples, 12 pinturas, upgrades e economia).
  - As builds exportadas conferem que o pacote `base` carrega e que o modelo do protótipo abre.
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
- Os logs e a pasta de mods passaram a ficar na pasta de saves (que muda no modo portátil).
- Os mods ligados são lidos do `settings.json` (`mods.enabled`).
- Fluxo de branches: o desenvolvimento acontece em `dev` e vai para `main` ao concluir cada etapa
  (antes: um branch por etapa).
