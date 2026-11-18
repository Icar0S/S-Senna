# Instalar o add-on do Blender (S-Senna CarKit)

O **S-Senna CarKit** é o add-on que transforma a preparação de um carro no Blender numa sequência de botões:
nomes, escala, eixos, materiais, soquetes, rodas, validação e exportação para o jogo. Para usá-lo, veja
[Adicionar um carro](adicionar-carro.md).

## 1. O que você precisa
- **Blender 5.2 LTS** ([download](https://www.blender.org/download/lts/)). O add-on usa o formato *Blender Extension*
  e não roda em versões antigas.
- O arquivo **`senna_carkit-<versão>.zip`**. Duas formas de conseguir:
  - **Gerar no seu computador**, a partir do repositório:
    ```bash
    tools/blender/build_extension.sh        # cria build/senna_carkit-0.1.0.zip
    ```
    (no Windows, rode no Git Bash; se o Blender não estiver no PATH, defina a variável `BLENDER` com o caminho
    do `blender.exe`, por exemplo `export BLENDER="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"`).
  - **Baixar do GitHub**: aba *Actions* → workflow **Blender (add-on)** → última execução verde → artefato
    **senna_carkit**.

## 2. Instalar
1. Abra o Blender.
2. **Arraste o `.zip` para dentro da janela do Blender** e confirme em "Install from Disk".
   - Alternativa: *Edit → Preferences → Get Extensions* → menu **⌄** (canto superior direito) → **Install from Disk…**
     → escolha o `.zip`.
3. Pronto: na Viewport 3D, aperte **N** e abra a aba **S-Senna**. O painel tem 5 seções, de cima para baixo:
   *1. Novo carro*, *2. Ferramentas*, *3. Validar*, *4. Exportar* e *5. Peças universais e aros*.

### Preferências (opcional)
*Edit → Preferences → Add-ons → S-Senna CarKit*: **Pasta padrão de exportação**, por exemplo
`<repositório>/godot/content/packs/base/cars`.

## 3. Atualizar ou remover
- **Atualizar**: gere/baixe o `.zip` novo e instale por cima (mesmo processo).
- **Remover**: *Edit → Preferences → Get Extensions* → S-Senna CarKit → **⌄** → **Uninstall**.

## 4. Para quem vai mexer no código do add-on
Em vez de reinstalar o `.zip` a cada mudança, aponte o Blender para a pasta do repositório:
*Edit → Preferences → Get Extensions → Repositories* → **+** → **Add Local Repository** → pasta `tools/blender`.
Assim o Blender carrega `tools/blender/senna_carkit/` direto, e o add-on lê o `conventions.json` do projeto Godot
(o `.zip` leva uma cópia dele).

Testes:
```bash
tools/blender/run_tests.sh           # testes puros (Python) + testes dentro do Blender, sem janela
tools/blender/run_tests.sh --pure    # só os testes puros (não precisa do Blender)
tools/blender/test_install.sh        # gera o .zip e instala num perfil temporário do Blender (não mexe no seu)
```
O código fica em `tools/blender/senna_carkit/`. As regras de validação (`validator.py`), os nomes (`naming.py`) e o
manifesto (`manifest.py`) são Python puro; só `operators.py`, `ui.py`, `exporter.py`, `scene_info.py` e `materials.py`
usam a API do Blender.

## 5. Problemas comuns
| Sintoma | Causa / solução |
|---|---|
| "This extension requires Blender 5.2.0 or newer" | Blender antigo: instale o 5.2 LTS |
| A aba **S-Senna** não aparece | Aperte **N** na Viewport 3D; confira se o add-on está ligado nas Preferências |
| "conventions.json não encontrado" | O `.zip` foi montado à mão: gere com `tools/blender/build_extension.sh` |
| Botão "Exportar" diz "corrija os erros da validação" | Rode **Validar** e corrija os itens vermelhos (veja [Adicionar um carro](adicionar-carro.md#5-validar)) |
