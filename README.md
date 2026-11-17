# S-Senna

**Jogo de corrida arcade para PC** inspirado na era de ouro do tuning — noite, neon, bodykits, rodas e vinis —
com o que faltava nos clássicos: **tela dividida para dois jogadores com dois controles** e um jeito fácil de
**colocar seus próprios carros no jogo**.

> 🚧 **Status: em desenvolvimento (fundação pronta).** Ainda não existe versão jogável: por enquanto o projeto abre
> uma tela de título. O plano completo está em [`docs/plano/`](docs/plano/README.md) e o andamento em
> [`docs/plano/PROGRESSO.md`](docs/plano/PROGRESSO.md).

---

## O que o jogo vai ter
- 🏁 Corridas de **Circuito, Sprint, Drag, Drift e Contra o Relógio**
- 🎮 **Dois jogadores no mesmo PC** em tela dividida (controle Xbox, PlayStation, Switch ou teclado)
- 🛠️ **Garagem única** com tudo: concessionária, visual, performance, coleção e modo foto
- 🎨 Customização visual profunda: para-choques, saias, aerofólios, rodas, pintura (perolada, camaleão, fosca…), **vinis em camadas**, neon, insulfilme, altura
- ⚙️ Performance simples: upgrades em níveis e um botão "deixar no máximo"
- 💾 Save local com backups automáticos e modo portátil
- 🧰 **S-Senna Studio**: programa separado para adicionar carros, peças, rodas e vinis
- 🪶 Visual inspirado na geração PS2: bonito e **leve**

## Como jogar (quando a primeira versão sair)
1. Baixe o `.zip` mais recente na página [**Releases**](../../releases).
2. Extraia em qualquer pasta.
3. Abra `S-Senna.exe` (Windows) ou `S-Senna.x86_64` (Linux).

PC mais fraco? Use o atalho **"S-Senna (modo leve)"** que vem no zip.

## Rodar a partir do código-fonte (para quem quer contribuir)
1. Instale o [Godot](https://godotengine.org/download) na versão indicada no arquivo `.godot-version` (versão padrão, **sem** .NET).
2. Instale o [Git LFS](https://git-lfs.com) e rode `git lfs install`.
3. Clone o repositório:
   ```bash
   git clone https://github.com/Icar0S/S-Senna.git
   ```
4. Rode `tools/scripts/jogar.bat` (Windows) ou `tools/scripts/jogar.sh` (Linux) — ou abra `godot/project.godot` no Godot e aperte **F5**.
   Os scripts procuram o Godot na variável de ambiente `GODOT` ou no PATH.
5. Para abrir o Studio: `tools/scripts/studio.bat` / `studio.sh`.

Mais detalhes (testes, exportação, problemas comuns) em [`docs/guias/ambiente-de-desenvolvimento.md`](docs/guias/ambiente-de-desenvolvimento.md).
Quer contribuir? Leia o [`CONTRIBUTING.md`](CONTRIBUTING.md): o desenvolvimento acontece na branch `dev`.

## Coloque seus carros no jogo
O fluxo será: **Blender** (com o add-on *S-Senna CarKit*) → **S-Senna Studio** → test drive → o carro aparece na Concessionária.
Veja [`docs/plano/04-padroes-de-arte-e-pipeline-de-carros.md`](docs/plano/04-padroes-de-arte-e-pipeline-de-carros.md).

## Tecnologias
[Godot 4](https://godotengine.org) (GDScript) · Jolt Physics · [Blender](https://www.blender.org) · glTF · GitHub Actions

## Licença
- Código: MIT — [`LICENSE`](LICENSE)
- Arte e áudio: CC BY-NC-SA 4.0 (padrão provisório) — [`LICENSE-ASSETS.md`](LICENSE-ASSETS.md)
- Créditos de terceiros: [`CREDITS.md`](CREDITS.md)

Este é um projeto de fã, gratuito e sem fins comerciais. Nomes de carros reais pertencem aos seus fabricantes.
