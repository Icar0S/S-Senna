# Guia — Pacotes de conteúdo

Tudo o que aparece no jogo (carros, peças, rodas, vinis, pinturas, sons, pistas) vem de **pacotes de conteúdo**:
pastas com arquivos JSON e modelos `.glb`. O jogo lê esses pacotes ao abrir; nenhum carro fica "escrito no código".

Formato completo de cada arquivo: [`docs/plano/03-formatos-de-dados.md`](../plano/03-formatos-de-dados.md).

## 1. Onde ficam os pacotes

| Fonte | Pasta | Carrega quando |
|---|---|---|
| Oficial (vem com o jogo) | `godot/content/packs/<pacote>/` | sempre |
| Mods do jogador | Windows: `%APPDATA%\S-Senna\mods\<pacote>\` · Linux: `~/.local/share/S-Senna/mods/<pacote>/` | quando o mod está ligado nas configurações (a tela de mods vem nas próximas etapas) |
| Pasta extra | qualquer pasta passada com `--content-dir=<pasta>` | sempre |

Exemplo, rodando do código com as fixtures de teste como pasta extra:
```bash
godot --path godot -- --content-dir=res://tests/fixtures/packs
```

## 2. Estrutura de um pacote

```
meu_pacote/
├── pack.json                              # obrigatório: id, nome, versão, depends, priority, aliases
├── cars/<slug>/car.json + model.glb
├── parts/universal/<slot>/<slug>/part.json + model.glb
├── wheels/<slug>/wheel.json + rim.glb
├── vinyls/<categoria>/vinyls.json + imagens
├── paints/paints.json
├── sounds/engine/<slug>/sound.json + .ogg
├── tracks/<slug>/track.json
├── upgrades/upgrades.json
└── economy.json
```

- O nome da pasta do pacote deve ser igual ao `id` do `pack.json` (o jogo avisa se não for).
- O ID de cada item segue `tipo:pacote/caminho` (ex.: `car:meu_pacote/fusca_77`) e a pasta do item deve ter o
  mesmo nome do fim do ID (`cars/fusca_77/`).
- Caminhos dentro dos JSON (`"model": "model.glb"`) são **relativos à pasta do próprio JSON**. Caminhos absolutos ou
  com `..` são recusados (um mod não pode apontar para fora da própria pasta).

## 3. Prioridade, dependências e aliases

- **`depends`**: pacotes que precisam ser carregados antes. Se faltar algum, o pacote é ignorado (com erro no relatório).
- **Substituir conteúdo de outro pacote**: declare o pacote em `depends` e use `priority` maior. Exemplo de um mod que
  troca o protótipo oficial:
  ```json
  { "schema": "pack", "schema_version": 1, "id": "meu_mod", "name": "Meu mod", "version": "1.0.0",
    "depends": ["base"], "priority": 10 }
  ```
  e, dentro dele, `cars/prototipo/car.json` com `"id": "car:base/prototipo"`.
- **`aliases`**: para renomear um item já publicado, mantenha o ID antigo apontando para o novo
  (`"car:base/nome_antigo": "car:base/nome_novo"`). **Nunca apague nem reutilize um ID publicado**: os saves dos
  jogadores dependem dele.

## 4. Peças universais em cada carro

Uma peça universal (ex.: um aerofólio) aparece para um carro quando:
1. o `slot` da peça é o pedido;
2. `compatible.cars` é `"*"` ou lista o carro, e `compatible.exclude` não lista;
3. o carro tem o soquete pedido em `fit.socket` (ex.: `spoiler`);
4. o carro aceita universais naquele slot: slots sem peças próprias (lips, canards, entradas de ar) sempre aceitam;
   slots com peças próprias só aceitam se alguma delas tiver `"accepts_universal": true`.

## 5. Quando algo dá errado

O jogo **nunca fecha** por causa de conteúdo com problema. Ele registra o que encontrou no log
(`s-senna.log`, ver o [guia do ambiente](ambiente-de-desenvolvimento.md)), sempre com arquivo, campo e motivo:

```
ERRO: .../cars/fusca_77/car.json [stats.drivetrain]: valor '4x4' inválido (válidos: FWD, RWD, AWD)
AVISO: .../cars/fusca_77/car.json [stats.grip]: valor 1.5 fora da faixa [0, 1]; usando 1
AVISO: .../cars/fusca_77/car.json [cor_favorita]: campo desconhecido (ignorado)
```

- **ERRO**: aquele item (carro, peça…) não é carregado; o resto do pacote continua.
- **AVISO**: o item carrega, mas algo foi corrigido ou ignorado.

No repositório, o CI vai além: `tools/ci/validate_content.sh` confere todos os JSON contra os schemas de `schemas/` e
**reprova** campos desconhecidos (para pegar erros de digitação no conteúdo oficial).

## 6. Conteúdo gerado por script

O carro de teste das fixtures e os placeholders do pacote `base` (Protótipo S-Senna, aros Básica 5 e Disco Aero,
Asa Simples) são gerados por `tools/fixtures/make_test_car.sh`. Não edite esses `.glb` nem os `car.json` deles à mão:
mude o gerador e rode o script de novo.
