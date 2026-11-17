# schemas/

JSON Schemas (Draft 2020-12) do conteúdo e dos saves do S-Senna: `car`, `part`, `wheel`, `pack`, `profile`…

Os schemas entram a partir da **Etapa 01**. Os formatos estão descritos em
[`docs/plano/03-formatos-de-dados.md`](../docs/plano/03-formatos-de-dados.md); mudou o formato, atualize o doc,
o schema e a migração no mesmo conjunto de commits.

Validação: `tools/ci/validate_content.sh`.
