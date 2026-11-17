# Guia — Saves e configurações

O S-Senna guarda tudo **no seu computador**: perfis (dinheiro, garagem, customizações), configurações e controles.
Formatos completos: [`docs/plano/03-formatos-de-dados.md`](../plano/03-formatos-de-dados.md) §13–§16.

## 1. Onde ficam

| Situação | Pasta |
|---|---|
| Windows | `%APPDATA%\S-Senna\` (cole na barra do Explorador) |
| Linux | `~/.local/share/S-Senna/` |
| **Modo portátil** | `save/` dentro da pasta do jogo |

```
<pasta de saves>/
├── settings.json          configurações (vídeo, áudio, idioma, mods ligados)
├── input.json             controles conhecidos e teclas
├── profiles/<id>/profile.json  (+ .bak1 .bak2 .bak3)
├── profiles/_lixeira/     perfis excluídos (nada é apagado de verdade)
├── mods/                  pacotes de mods
└── logs/s-senna.log       registro da última execução (+ 4 anteriores)
```

## 2. Modo portátil
Crie um arquivo vazio chamado **`portable.txt`** na mesma pasta do executável (`S-Senna.exe`). A partir daí
saves, configurações, logs e mods ficam em `save/` ao lado do jogo — dá para levar tudo num pendrive.

## 3. Backups e recuperação
- Cada vez que um perfil é salvo, a versão anterior vira `profile.json.bak1` (e a `.bak1` vira `.bak2`, até `.bak3`).
- A gravação é **atômica**: o jogo grava um arquivo temporário, confere e só então troca. Se faltar espaço ou o
  PC desligar no meio, o save anterior continua inteiro.
- Cada perfil tem um **checksum**. Se o `profile.json` estiver estragado ou tiver sido editado à mão, o jogo usa
  o backup mais recente que estiver bom e avisa que recuperou.
- Saves de uma **versão mais nova** do jogo abrem só para leitura: a versão antiga nunca os sobrescreve.

> Quer editar um save à mão? Edite o `settings.json` à vontade. No `profile.json` o checksum vai acusar a mudança
> e o jogo vai preferir o backup — use isso só para estudar o formato.

## 4. Peças de mods
Se você desligar um mod, as peças, rodas e vinis dele **continuam gravados** no seu perfil. O jogo mostra as peças
originais no lugar enquanto o mod estiver desligado; ao religá-lo, tudo volta como estava.

## 5. Exportar e importar
O `SaveManager` exporta um perfil para um `.zip` e importa de volta (por exemplo, para levar para outro PC).
Por enquanto isso é usado pelos testes e pela garagem futura (Etapa 09), que terá os botões.

## 6. Tela de teste (para desenvolvedores)
```bat
tools\scripts\jogar.bat res://game/sandbox/save_debug.tscn
```
Cria, carrega, duplica e exclui perfis, e tem dois botões de dinheiro: um que salva com o autosave e outro que só
marca a mudança — ela é gravada quando você **fecha a janela pelo X**.

## 7. `settings.json`
Gerado na primeira execução com valores padrão. Pode ser editado com o jogo fechado; valores inválidos são
corrigidos ao abrir. Para ligar um mod, coloque o ID dele em `"mods": { "enabled": ["meu_mod"] }`.
