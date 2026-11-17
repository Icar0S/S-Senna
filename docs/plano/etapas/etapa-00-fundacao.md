# Etapa 00 — Fundação do repositório e do projeto Godot

> **Marco:** A · **Depende de:** nada · **Tamanho:** M
> **Resultado:** repositório organizado, projeto Godot abrindo, Jogo e Studio iniciando, CI verde.

## Objetivo
Deixar a base pronta para todas as outras etapas: estrutura de pastas, configurações do Godot, convenções,
testes automatizados, CI, scripts para rodar do código-fonte e as licenças.

## Entregáveis
- Estrutura de pastas de `02-arquitetura.md` §1 (com um `README.md` curto em `core/`, `game/`, `studio/` explicando a responsabilidade).
- `godot/project.godot` com as configurações de `02-arquitetura.md` §8.
- `boot/boot.tscn` que abre o Jogo ou o Studio.
- Telas provisórias: `game/main_menu/main_menu.tscn` ("S-Senna" + versão) e `studio/studio_main.tscn` ("S-Senna Studio").
- 4 presets de exportação (Jogo/Studio × Windows/Linux).
- gdUnit4 instalado em `godot/addons/` com versão fixada.
- CI no GitHub Actions.
- Scripts de execução e de captura de tela.
- Arquivos: `.godot-version`, `.gitignore`, `.gitattributes`, `.editorconfig`, `LICENSE`, `LICENSE-ASSETS.md`, `CREDITS.md`, `CHANGELOG.md`, `CONTRIBUTING.md`.

## Tarefas (ordem sugerida)
1. **Versão do Godot**: confirmar a estável mais recente da série 4.7 em godotengine.org e gravar em `.godot-version` (ex.: `4.7.2`).
2. **`tools/ci/install_godot.sh`**: baixa o binário Linux x86_64 e os *export templates* da versão do `.godot-version` a partir de `github.com/godotengine/godot-builds/releases`, confere o SHA-512 publicado e instala em `~/.local/share/godot/`. Idempotente. Usado no CI e no ambiente de nuvem do agente.
   - Os *export templates* (~1,3 GB) só são baixados com a opção `--templates`, e só os de Linux/Windows x86_64 são extraídos (ver Notas de implementação).
3. **`.gitignore`**: `.godot/`, `/build/`, `*.tmp`, `*.blend1`, `__pycache__/`, `export_credentials.cfg`.
   - ⚠️ No Godot 4 os arquivos `*.import` **devem ser commitados** (guardam as opções de importação).
4. **`.gitattributes`**:
   - `* text=auto eol=lf`, `*.bat text eol=crlf`
   - LFS: `*.glb *.blend *.png *.jpg *.jpeg *.webp *.exr *.hdr *.ogg *.wav *.mp3 *.ttf *.otf *.kra *.psd`
   - Exceções: `godot/tests/fixtures/** !filter !diff !merge` e `godot/addons/** !filter !diff !merge` (fora do LFS para o CI não gastar banda; `!` em vez de `-` para manter o diff de texto dos JSON — ver Notas de implementação).
5. **`project.godot`**: nome, versão, pasta de usuário própria, Forward+, Jolt, 120 Hz, interpolação de física, *stretch*, tipagem obrigatória, idioma padrão pt_BR, autoload `Log`.
6. **Boot**: `boot.gd` verifica `OS.has_feature("studio")` ou `"--studio" in OS.get_cmdline_user_args()`; carrega a cena do Studio pelo **caminho em texto** (sem `preload`) para a pasta `studio/` poder ser excluída da exportação do jogo.
7. **Autoload `Log`** (`core/util/log.gd`): níveis `debug/info/warn/error`, grava em `user://logs/s-senna.log` com rotação simples (5 arquivos).
8. **Presets de exportação** (`export_presets.cfg`) conforme `02-arquitetura.md` §2 — incluir filtro `*.json`, feature `studio` nos presets do Studio, exclusões de `tests/*`, `reports/*` (relatórios do gdUnit4), `addons/gdUnit4/*` e (no Jogo) `studio/*`.
9. **gdUnit4**: copiar a versão estável compatível com Godot 4.7 para `godot/addons/gdUnit4/`; registrar versão e licença em `godot/addons/README.md`.
10. **Qualidade**: `gdlintrc` na raiz; `tools/ci/lint.sh` (`gdformat --check` + `gdlint` em `godot/` excluindo `addons/`).
11. **Testes**: `tools/ci/test.sh` rodando o runner de linha de comando do gdUnit4 em modo headless (seguir a documentação da versão fixada; ex.: `GODOT_BIN=... godot/addons/gdUnit4/runtest.sh -a res://tests`).
12. **Arquitetura**: `tools/ci/check_architecture.sh` (regras de `02-arquitetura.md` §4).
13. **Validação de conteúdo**: `tools/ci/validate_content.sh` (por enquanto só confere que todo `.json` é JSON válido; os schemas entram na Etapa 01).
14. **CI** `.github/workflows/ci.yml`: em `push` e `pull_request`; jobs `lint`, `test` (instala Godot com cache), `architecture`, `content`, `export` (exporta e confere as builds Linux) e `screenshot` (captura as telas de título). Checkout **sem LFS**.
15. **Scripts de execução**: `tools/scripts/jogar.sh`, `jogar.bat`, `studio.sh`, `studio.bat` — procuram o Godot na variável `GODOT` ou no PATH e mostram mensagem amigável se não acharem.
16. **Captura de tela** (para o agente conferir o visual): `godot/core/debug/capture.gd` (espera N quadros, salva `get_viewport().get_texture().get_image()` em PNG e fecha) + `tools/scripts/screenshot.sh <cena> <saida.png> [largura altura]` usando `xvfb-run` e `--rendering-method gl_compatibility`. Documentar os pacotes de sistema necessários.
17. **Licenças e docs**: `LICENSE` (MIT), `LICENSE-ASSETS.md` (🧑 decisão do dono; padrão sugerido: **CC BY-NC-SA 4.0**), `CREDITS.md` (vazio com cabeçalho), `CHANGELOG.md`, `CONTRIBUTING.md` (fluxo: uma etapa = um branch = um PR; lint/testes antes do PR; convenções).
18. **GitHub**: modelos de issue (`bug.yml`, `ideia.yml`; o `novo-carro.yml` entra na Etapa 15), milestones para os Marcos A–F, labels (`etapa-NN`, `conteudo`, `bug`, `playtest`).

## Detalhes técnicos
- Rodar o jogo do código: `godot --path godot`; Studio: `godot --path godot -- --studio`.
- Exportar localmente: `godot --headless --path godot --export-release "Jogo - Linux" ../build/linux/S-Senna.x86_64`.
- Primeiro teste de exportação deve provar que um `.json` qualquer em `res://content/` está presente na build (abrir com `FileAccess` no executável exportado).
  - Implementado como **self-check**: `tools/ci/export.sh` roda cada build com `-- --self-check`; a cena de boot imprime uma linha `SELF_CHECK {...}` (JSON de conteúdo legível, `studio/` presente ou não, `tests/` ausente) e fecha.

## Critérios de aceite
### 🤖 Automáticos
- [x] CI verde (lint, testes, arquitetura, conteúdo, exportação, captura) no push em `dev` antes do merge na `main`.
- [x] `godot --headless --path godot --quit` sem erros nem avisos de script (conferido por `tools/ci/test.sh`).
- [x] Teste: boot sem argumento carrega `main_menu`; boot com `--studio` carrega `studio_main` (`tests/unit/test_boot.gd`).
- [x] Teste: `Log` grava em arquivo (`tests/unit/test_log.gd`).
- [x] Exportação "Jogo - Linux" e "Studio - Linux" geram executáveis; a build do Jogo **não** contém `studio/`; o JSON de teste está presente (`tools/ci/export.sh`, conferido em Linux e Windows).
- [x] `screenshot.sh` gera um PNG da tela de título.
### 🎮 Manuais (dono)
- [x] Rodar `jogar.bat` e `studio.bat` no Windows com o Godot instalado (defina a variável `GODOT` ou ponha o `godot.exe` no PATH) — aprovado pelo dono em 2026-11-17.
- [ ] Rodar `tools/scripts/setup_github.sh` (labels e milestones) e trocar a branch padrão do GitHub para `main`.

## Testes a escrever
`tests/unit/test_boot.gd`, `tests/unit/test_log.gd`.

## Armadilhas
- JSON fora da build (filtro de inclusão).
- Fim de linha CRLF quebrando scripts `.sh` (resolver no `.gitattributes`).
- `.godot/` commitado por engano (cache enorme).

## Fora do escopo
Qualquer funcionalidade de jogo.

## Notas de implementação (2026-11-16)
Versões fixadas: **Godot 4.7.2**, **gdUnit4 6.2.3**, **gdtoolkit 4.5.0**. O que saiu diferente do texto original e por quê:

| Item | Como ficou | Motivo |
|---|---|---|
| Fluxo de branches | `dev` (trabalho) → `main` (etapa concluída), sem branch/PR por etapa | Decisão do dono; `CLAUDE.md`, `README.md` do plano e `CONTRIBUTING.md` atualizados |
| Export templates no `install_godot.sh` | Só com `--templates`; extrai apenas Linux/Windows x86_64 | O arquivo tem ~1,3 GB; lint/testes/captura não precisam dele, só o job `export` |
| `.gitattributes` das exceções do LFS | `!filter !diff !merge` em vez de `-filter -diff -merge`; inclui `godot/addons/**` | `-diff` faria os JSON das fixtures (golden files) aparecerem como binário; o gdUnit4 tem PNGs que o CI (sem LFS) precisa |
| Presets de exportação | Excluem também `reports/*` | Os relatórios HTML do gdUnit4 ficam em `godot/reports/` e estavam entrando nas builds |
| Prova de conteúdo na build | Argumento `-- --self-check` na cena de boot + `tools/ci/export.sh` | Forma automática de "abrir com `FileAccess` no executável exportado"; reutilizável nas próximas etapas |
| CI | Jobs extras `export` e `screenshot` | Tornam automáticos os critérios 🤖 de exportação e de captura de tela |
| Lógica de boot/log | `BootResolver`, `BootSelfCheck`, `LogWriter`, `CmdlineArgs` (`RefCounted`) + nós finos | Regra "lógica testável, nós finos" |
| `gdformatrc` | Arquivo extra na raiz (além do `gdlintrc`) | Excluir `addons/` e `.godot/` também do `gdformat` |
| Labels e milestones do GitHub | Script `tools/scripts/setup_github.sh` (usa o GitHub CLI) | O agente não tem acesso autenticado à API do GitHub; fica como pendência do dono |
| Traduções (`ui/i18n/strings.csv`) | Ainda não criadas | As telas provisórias só mostram nome e versão (não traduzíveis); o arquivo entra com a primeira tela com texto |

Outros pontos úteis para as próximas etapas:
- Em um clone novo é preciso **importar o projeto** antes de rodar (`--import`), senão as classes com `class_name` não são encontradas. Os scripts `jogar`, `studio`, `test.sh`, `export.sh` e `screenshot.sh` já fazem isso.
- O repositório do gdUnit4 mudou para `github.com/godot-gdunit-labs/gdUnit4`.
- No Windows, o `gdformat` regrava os arquivos com CRLF; o `.gitattributes` normaliza para LF no commit.
