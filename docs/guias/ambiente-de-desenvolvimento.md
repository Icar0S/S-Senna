# Guia — Ambiente de desenvolvimento

Como rodar o S-Senna a partir do código-fonte, rodar os testes e usar os scripts do repositório.

## 1. O que instalar

| Ferramenta | Versão | Para quê | Obrigatório? |
|---|---|---|---|
| [Godot](https://godotengine.org/download) (padrão, **sem** .NET) | a do arquivo `.godot-version` (4.7.2) | Rodar o Jogo e o Studio | Sim |
| [Git](https://git-scm.com) + [Git LFS](https://git-lfs.com) | atuais | Clonar o repositório (`git lfs install` uma vez) | Sim |
| Python 3.9+ e `pip install -r tools/ci/requirements.txt` | — | Lint (`gdformat`/`gdlint`) e validação de conteúdo (`check-jsonschema`) | Só para contribuir |
| Export templates do Godot | a mesma do Godot | Gerar builds (`tools/ci/export.sh`) | Só para exportar |

No Windows, os scripts `.sh` rodam no **Git Bash** (vem com o Git).

### Como os scripts acham o Godot
Nesta ordem: variável de ambiente **`GODOT`** (caminho completo do executável) → variável `GODOT_BIN` →
`godot` ou `godot4` no PATH → `~/.local/bin/godot`.

```bat
:: Windows (uma vez; depois feche e abra o terminal)
setx GODOT "C:\Godot\Godot_v4.7.2-stable_win64.exe"
```
```bash
# Linux
export GODOT="$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64"
# ou, para instalar automaticamente em ~/.local/share/godot (confere o SHA-512):
tools/ci/install_godot.sh
```

> No Windows, para rodar os scripts de `tools/ci/` pelo Git Bash, aponte `GODOT` para o executável
> `..._win64_console.exe`: é ele que mostra a saída no terminal.

## 2. Rodar

| O quê | Windows | Linux |
|---|---|---|
| Jogo | `tools\scripts\jogar.bat` | `tools/scripts/jogar.sh` |
| S-Senna Studio | `tools\scripts\studio.bat` | `tools/scripts/studio.sh` |

Ou direto: `godot --path godot` (Jogo) e `godot --path godot -- --studio` (Studio).
Também dá para abrir `godot/project.godot` no editor e apertar **F5**.

Na primeira execução os scripts importam o projeto (cria a pasta `godot/.godot/`, que **não** vai para o Git).

Os logs ficam em `%APPDATA%\S-Senna\logs\s-senna.log` (Windows) ou `~/.local/share/S-Senna/logs/s-senna.log`
(Linux) — ou em `save/logs/` no modo portátil; as 4 execuções anteriores ficam em `s-senna.1.log` … `s-senna.4.log`.
Saves e configurações: ver [`saves-e-configuracoes.md`](saves-e-configuracoes.md).

Para abrir uma cena específica (por exemplo a tela de teste de perfis), passe o caminho dela:
`tools\scripts\jogar.bat res://game/sandbox/save_debug.tscn`.

## 3. Conferir antes de enviar

```bash
tools/ci/lint.sh                 # gdformat --check + gdlint   (tools/ci/lint.sh --fix formata)
tools/ci/test.sh                 # testes gdUnit4 headless (+ confere que o projeto inicia sem erros/avisos)
tools/ci/validate_content.sh     # todo .json é JSON válido e bate com o schema de schemas/
tools/ci/check_architecture.sh   # regras de dependência entre core/, game/ e studio/
```

- Rodar só um arquivo de teste: `tools/ci/test.sh -a res://tests/unit/test_log.gd`.
- Relatório HTML dos testes: `godot/reports/` (fora do Git).
- As duas linhas `ERROR: ... remote port` / `Remote Debugger` no começo da saída dos testes são esperadas
  (truque do gdUnit4 para o depurador não travar o terminal).
- No editor, os testes também rodam pelo painel **GdUnit** (plugin já habilitado no projeto).

O mesmo roda no GitHub Actions (`.github/workflows/ci.yml`) a cada push em `dev`/`main` e em pull requests.

## 4. Exportar builds

```bash
tools/ci/export.sh            # plataforma desta máquina
tools/ci/export.sh all        # Linux + Windows
```
Saída em `build/<plataforma>/`. O script também **confere** as builds da própria plataforma: executa cada uma com
`-- --self-check` e verifica que o JSON de conteúdo está lá dentro, que a build do Jogo não contém `studio/`
e que nenhuma contém `tests/`.

Os export templates são instalados pelo editor (*Editor → Gerenciar modelos de exportação*) ou, no Linux/CI,
por `tools/ci/install_godot.sh --templates` (~1,3 GB de download).

## 5. Captura de tela (conferência visual)

```bash
tools/scripts/screenshot.sh res://game/main_menu/main_menu.tscn build/screenshots/menu.png
tools/scripts/screenshot.sh godot/studio/studio_main.tscn saida.png 1920 1080
CAPTURE_FRAMES=120 tools/scripts/screenshot.sh <cena> <saida.png>   # espera mais quadros antes de capturar
```

A cena é aberta por `godot/core/debug/capture.tscn`, que espera alguns quadros, salva o PNG e fecha.
Sempre no modo **Compatibility** (OpenGL), o único que funciona sem placa de vídeo.

- **Com tela** (Windows, Linux desktop): uma janela abre por um instante.
- **Sem tela** (CI, nuvem): o script usa `xvfb-run` com renderização por software (Mesa).
  Pacotes necessários no Debian/Ubuntu:
  ```bash
  sudo apt-get install -y --no-install-recommends \
    xvfb xauth libgl1 libgl1-mesa-dri libxcursor1 libxinerama1 libxi6 libxrandr2 libxkbcommon0
  ```
  (`mesa-vulkan-drivers` é opcional; só seria usado para testar o Forward+ por software.)

## 6. Conteúdo gerado por script
Os modelos de teste e os placeholders do pacote `base` (Protótipo S-Senna, aros, aerofólio) são gerados por código:
```bash
tools/fixtures/make_test_car.sh
```
O script reescreve os `.glb` e os `car.json` correspondentes e reimporta o projeto. O resultado é determinístico
(rodar duas vezes gera arquivos idênticos). Mais detalhes em [`pacotes-de-conteudo.md`](pacotes-de-conteudo.md).

## 7. GitHub (labels e milestones)
`tools/scripts/setup_github.sh` cria as labels (`etapa-NN`, `conteudo`, `bug`, `ideia`, `playtest`) e as milestones
dos Marcos A–F. Requer o [GitHub CLI](https://cli.github.com) autenticado (`gh auth login`).

## 8. Problemas comuns

| Sintoma | Causa / solução |
|---|---|
| `Could not find type "..." in the current scope` ao rodar | Projeto ainda não importado: rode `godot --headless --path godot --import` (os scripts fazem isso sozinhos) |
| Script `.sh` falha com `\r: command not found` | Fim de linha CRLF. O `.gitattributes` força LF; rode `git add --renormalize .` |
| `gdformat` reclama depois de editar no Windows | Rode `tools/ci/lint.sh --fix` (o Git normaliza o fim de linha no commit) |
| Exportação "não gerou" o executável | Export templates da versão do `.godot-version` não instalados |
| Captura sai preta ou falha no Linux sem tela | Faltam os pacotes do Xvfb/Mesa da seção 5 |
