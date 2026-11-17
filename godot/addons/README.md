# addons/ — plugins de terceiros

Cada plugin entra com a **versão fixada** e a licença registrada aqui e em [`CREDITS.md`](../../CREDITS.md).
Não edite o código dos plugins: para atualizar, substitua a pasta inteira pela nova versão e atualize esta tabela.

| Plugin | Versão | Licença | Origem | Uso |
|---|---|---|---|---|
| [gdUnit4](gdUnit4/) | **6.2.3** (tag `v6.2.3`, compatível com Godot 4.7) | MIT ([`gdUnit4/LICENSE`](gdUnit4/LICENSE)) | <https://github.com/godot-gdunit-labs/gdUnit4> | Testes unitários e de cena (`tools/ci/test.sh`) |

## Observações
- Esta pasta fica **fora do Git LFS** (ver `.gitattributes`): o CI faz checkout sem LFS e precisa dos plugins inteiros.
- O gdUnit4 **não entra nas builds** (excluído nos presets de exportação, junto com `tests/` e `reports/`).
- O lint (`gdformat`/`gdlint`) e o aviso de tipagem obrigatória não se aplicam a `addons/`.

## Como atualizar o gdUnit4
1. Baixe o código-fonte da tag desejada em <https://github.com/godot-gdunit-labs/gdUnit4/releases>.
2. Apague `godot/addons/gdUnit4/` e copie a pasta `addons/gdUnit4/` do arquivo baixado.
3. Abra o projeto no Godot (ou rode `godot --headless --path godot --import`) para gerar os arquivos `.uid`/`.import`.
4. Rode `tools/ci/test.sh`, atualize a tabela acima e o `CREDITS.md`.
