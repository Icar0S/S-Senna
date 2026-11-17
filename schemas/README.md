# schemas/

JSON Schemas (Draft 2020-12) do conteúdo e dos saves do S-Senna: `car`, `part`, `wheel`, `pack`, `profile`…

Um arquivo por tipo, escolhido pelo campo `"schema"` de cada JSON: `pack`, `car`, `part`, `wheel`, `vinyl_set`,
`paint_catalog`, `sound_profile`, `track`, `upgrades`, `economy` e `conventions` (conteúdo) e `profile`,
`settings` e `input` (saves — estes aceitam campos extras, porque o jogo preserva campos de versões futuras). Definições compartilhadas
(IDs, cores, caminhos relativos, pintura) ficam em `common.schema.json`.

Os schemas são **estritos** (campo desconhecido reprova no CI), para pegar erros de digitação no conteúdo oficial.
O jogo é mais tolerante: campo desconhecido vira só aviso (doc 03 §1). Slots, soquetes e materiais são conferidos
pelo jogo contra o `conventions.json` (os schemas só checam o formato do nome).

Os formatos estão descritos em
[`docs/plano/03-formatos-de-dados.md`](../docs/plano/03-formatos-de-dados.md); mudou o formato, atualize o doc,
o schema e a migração no mesmo conjunto de commits.

Validação: `tools/ci/validate_content.sh`.
