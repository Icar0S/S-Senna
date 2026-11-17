# studio/ — o S-Senna Studio

Ferramenta de criação: adicionar carros, peças, rodas e vinis, conferir o resultado e fazer test drive.
Usa o **mesmo código** de montagem e renderização do jogo (`core/`), então o que aparece aqui é idêntico ao jogo.

**Regra de dependência:** `studio/` pode usar `core/`, `ui/` e `content/`; do Jogo, só as cenas de
`game/sandbox/` (para o test drive).

Esta pasta é **excluída das builds do Jogo**. Por isso a cena de boot carrega `studio_main.tscn` pelo
caminho em texto (sem `preload`) e nada fora daqui pode referenciar estes arquivos diretamente.

Rodar do código-fonte: `tools/scripts/studio.sh` / `studio.bat` (ou `godot --path godot -- --studio`).
