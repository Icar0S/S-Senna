# Etapa 02 — Sistema de save (perfis, configurações, backups, migrações)

> **Marco:** A · **Depende de:** 01 · **Tamanho:** M
> **Resultado:** o jogador nunca perde o que fez: perfis, garagem, customizações e configurações salvos localmente com segurança.

## Objetivo
Salvar tudo localmente, de forma **atômica**, com **backups automáticos**, **migração entre versões** e **modo portátil**.

## Entregáveis
- Autoload `SaveManager` e `Settings`.
- Classes `ProfileData`, `CarConfig`, `SettingsData`, `InputBindingsData` com `to_dict()` / `from_dict()`.
- Pasta `core/save/migrations/` com o mecanismo de migração (e uma migração de exemplo testada).
- Testes de robustez (arquivo corrompido, falta de espaço simulada, migração).

## Onde ficam os saves
| Situação | Pasta |
|---|---|
| Windows (padrão) | `%APPDATA%\S-Senna\` |
| Linux (padrão) | `~/.local/share/S-Senna/` |
| **Modo portátil** | se existir um arquivo `portable.txt` ao lado do executável → `<pasta do jogo>/save/` |
| Testes | pasta temporária injetada no `SaveManager` |

Estrutura:
```
<pasta de saves>/
├── settings.json
├── input.json
├── profiles/<profile_id>/profile.json (+ .bak1 .bak2 .bak3)
├── photos/            (Etapa 09)
├── ghosts/            (Etapa 11)
└── logs/
```
> O `SaveManager` trabalha com um **caminho base próprio** (não usa `user://` diretamente), para o modo portátil funcionar.

## Tarefas
1. **Caminho base**: resolver modo portátil (`OS.get_executable_path().get_base_dir()`), senão `ProjectSettings.globalize_path("user://")`. Expor `get_base_dir()`.
2. **Escrita atômica + backups**:
   1. Serializar `data` → calcular `checksum` SHA-256 (`HashingContext`).
   2. Gravar `profile.json.tmp` e fechar.
   3. Girar: apagar `.bak3`, `.bak2→.bak3`, `.bak1→.bak2`, `profile.json→.bak1`.
   4. Renomear `.tmp → profile.json`.
   5. Se qualquer passo falhar: manter o arquivo antigo, logar erro, emitir `save_failed` (a UI mostra aviso).
3. **Leitura com recuperação**: tentar `profile.json`, depois `.bak1..3`; validar JSON + checksum; emitir `save_recovered(origem)` quando usar backup.
4. **Migrações**: `Migrations.apply(dict, schema, from_version) -> dict`; arquivos `profile_v1_to_v2.gd` etc. Saves de versão **mais nova** que o jogo: abrir só leitura e avisar.
5. **API de perfis**: `list_profiles()`, `create_profile(nome, sandbox)`, `load_profile(id)`, `save_profile(id)`, `delete_profile(id)` (move para `profiles/_lixeira/`), `duplicate_profile(id)`, `export_profile(id, caminho_zip)` / `import_profile(caminho_zip)` com `ZIPPacker`/`ZIPReader`.
6. **Autosave**: `request_save(id, motivo)` agrupa pedidos (≈1 s) e salva; salvar também ao fechar o jogo (`NOTIFICATION_WM_CLOSE_REQUEST`); sinal `saved(id)` para o ícone de "salvando".
7. **`CarConfig`**: implementar exatamente `03-formatos-de-dados.md` §13; `CarConfig.create_default(car_def)`; funções puras para trocar peça/pintura/roda (usadas depois pela garagem).
8. **Conteúdo ausente**: IDs desconhecidos ficam no save intactos; `CarConfig.resolve(content_db)` devolve a versão "efetiva" (com originais no lugar) + lista de ausências para a UI.
9. **`Settings`**: carregar/salvar `settings.json`; aplicar modo de janela, resolução, vsync, limite de FPS, volumes (buses), idioma. Valores padrão sensatos na primeira execução.
10. **`input.json`**: só o formato e a persistência (o uso real é na Etapa 07).
11. **Modo Colecionador (sandbox)**: flag no perfil; `Economy` (Etapa 09) consulta essa flag.

## Critérios de aceite
### 🤖 Automáticos
- [x] Ida e volta (`to_dict` → JSON → `from_dict`) de perfil com 50 carros configurados é idêntica (`test_profile_store.gd`).
- [x] Arquivo principal truncado → carrega do `.bak1` e emite `save_recovered` (`test_profile_store.gd`, `test_save_manager.gd`).
- [x] Checksum errado → recuperação pelo backup.
- [x] Migração v1→v2 de exemplo aplicada a um "golden file" (`tests/fixtures/saves/profile_v1.json`).
- [x] Save de versão futura não é sobrescrito (nem pelo perfil carregado, nem por outro objeto com o mesmo ID).
- [x] Modo portátil muda a pasta base.
- [x] Nomes com acentos e emojis funcionam; caminhos com espaços funcionam.
- [x] 20 pedidos de save em 100 ms resultam em 1 escrita (`test_save_manager.gd`, com tempo real).
- [x] Peça de mod ausente não some do save.
- [x] Disco cheio / escrita silenciosamente corrompida (simulados com `FileOps` falho): o save anterior continua intacto.
### 🎮 Manuais
- [ ] Fechar o jogo pelo "X" da janela salva o perfil — use a tela de teste (duplo clique em `tools\scripts\perfis.bat`),
  crie/carregue um perfil, clique em **"+1000 sem salvar"**, feche pelo X e abra de novo: o dinheiro deve ter aumentado.

## Armadilhas
- Renomear sobre arquivo existente no Windows: por isso a rotação de backups antes do rename final.
- Nunca salvar dentro de `res://` (somente leitura na build).

## Fora do escopo
Telas de seleção de perfil (entram com a garagem, Etapa 09; aqui pode haver uma tela de debug simples).

## Notas de implementação (2026-11-17)
| Item | Como ficou | Motivo |
|---|---|---|
| Checksum | SHA-256 do texto **canônico** de `data` | O JSON relido traz todo número como float (`2026` → `2026.0`); com o texto cru o checksum nunca bateria. Doc 03 §14 |
| Escrita | `.tmp` → **relê e compara** → gira backups → renomeia | A releitura pega "disco cheio silencioso" (gravação que diz OK mas grava lixo) |
| Falhas simuladas | `FileOps` injetável (`ProfileStore`, `SaveManager.configure`, `Settings.configure`) | Testar falta de espaço sem encher o disco de verdade |
| Lógica × autoload | `ProfileStore`/`SaveScheduler` (lógica, testáveis) + `SaveManager` (sinais, autosave, fechar) | Regra "lógica em RefCounted, nós finos" |
| Salvar ao fechar | `NOTIFICATION_WM_CLOSE_REQUEST` **e** `_exit_tree` (cobre `get_tree().quit()`) | Também salva o que foi marcado com `mark_dirty` e não estava agendado |
| Versão futura | Somente leitura; além disso, nada sobrescreve um arquivo do disco que seja de versão mais nova | Proteção contra um perfil recriado com o mesmo ID |
| Migração de exemplo | `migrations/example_v1_to_v2.gd` (modelo, **não registrado**) + golden v1 real | As versões atuais continuam 1; o mecanismo e o modelo ficam prontos e testados |
| Campos desconhecidos | Preservados em perfil, carro, `settings.json` e `input.json` | Um save de versão nova que passa por esta versão não perde dados |
| `settings.json` / `input.json` | Escrita atômica com 1 backup, sem checksum; padrões gravados na 1ª execução | O jogador pode editar à mão |
| Padrões de vídeo | Janela 1280×720, sem upscaler | Tela cheia por padrão atrapalha rodar do código e a captura de tela; a tela de opções vem depois |
| Aplicar vídeo | Ignorado em headless e quando a linha de comando já define a janela | A captura (`screenshot.sh`) usa `--windowed --resolution` |
| Mods | `ContentDB` lê `settings.mods.enabled` e a pasta `<saves>/mods` | Fecha a pendência da Etapa 01; funciona no modo portátil |
| Logs | Também seguem a pasta base (`<saves>/logs`) | Modo portátil completo |
| Traduções | `godot/ui/i18n/strings.csv` (pt_BR, en) criado agora; os `.translation` gerados são commitados | O `Settings` aplica o idioma; commitados para um clone novo não reclamar antes da 1ª importação |
| Tela de teste | `game/sandbox/save_debug.tscn` | Para o 🎮 de fechar pelo X (a tela de perfis de verdade vem na Etapa 09) |
| Schemas | `profile`, `settings`, `input` em `schemas/` (aceitam campos extras) | O CI valida o golden file e os arquivos de exemplo |
