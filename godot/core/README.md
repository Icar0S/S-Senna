# core/ — código compartilhado

Tudo que o **Jogo** e o **S-Senna Studio** usam em comum: conteúdo (ContentDB), save, veículo (física e montagem),
entrada, renderização, câmeras, depuração e utilitários.

**Regra de dependência (conferida no CI por `tools/ci/check_architecture.sh`):**
`core/` só pode depender de `core/` e de `addons/`. Nunca referencia as pastas do Jogo ou do Studio,
nem o autoload de sessão do Jogo.

| Pasta | Responsabilidade |
|---|---|
| `content/` | ContentDB, definições (`CarDef`…), loaders, validação, `conventions.json` |
| `save/` | SaveManager, migrações, Settings |
| `vehicle/` | Física, montagem visual (CarAssembler), rodas, áudio do motor |
| `input/` | InputRouter, PlayerSlot, dispositivos |
| `render/` | Shaders, biblioteca de materiais, presets de qualidade |
| `camera/` | Câmeras de perseguição e de garagem |
| `debug/` | Telemetria, overlays, captura de tela (`capture.tscn`) |
| `util/` | `Log` (autoload), `LogWriter`, `CmdlineArgs`, helpers |

Lógica em classes `RefCounted` testáveis; nós finos. Detalhes em `docs/plano/02-arquitetura.md`.
