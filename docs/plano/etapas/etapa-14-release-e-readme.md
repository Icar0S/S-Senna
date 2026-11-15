# Etapa 14 — Empacotamento, releases e README final

> **Marco:** F · **Depende de:** todas as anteriores · **Tamanho:** M
> **Resultado:** qualquer pessoa baixa um `.zip`, extrai e joga — e o README explica tudo em poucos minutos de leitura.

## Objetivo
Automatizar a geração das builds, publicar no GitHub Releases e deixar o README à altura de um projeto público.

## Entregáveis
- `.github/workflows/release.yml`: ao criar uma tag `vX.Y.Z`, exporta **Jogo** e **Studio** para Windows e Linux, compacta, gera `SHA256SUMS.txt` e publica um Release com as notas do `CHANGELOG.md`.
- `tools/ci/export.sh` (o mesmo script usado localmente).
- Zip do jogo contendo: executável + `.pck`, atalho/batch **"S-Senna (modo leve)"** (`--rendering-method gl_compatibility`), `LEIA-ME.txt` curto, `LICENSE`, `CREDITS.md`, e um `portable.txt.exemplo` explicando o modo portátil.
- README final (estrutura abaixo), em pt-BR, com versão em inglês (`README.en.md`) opcional.
- Versão exibida na tela de título vinda de `application/config/version`.
- Opcional: página no **itch.io** (via `butler`) e instalador Windows com **Inno Setup** — só se o dono quiser.

## Estrutura do README final
1. **Logo + uma frase** + GIF curto (garagem → corrida a dois).
2. **Baixar e jogar** (3 passos):
   1. Baixe o `.zip` mais recente em *Releases*.
   2. Extraia em qualquer pasta.
   3. Abra `S-Senna.exe` (Windows) ou `S-Senna.x86_64` (Linux).
   - Aviso do Windows SmartScreen ("Mais informações → Executar assim mesmo") — o jogo não é assinado.
   - PC fraco? Use **"S-Senna (modo leve)"**.
3. **Controles** (tabela controle/teclado — da Etapa 07).
4. **Jogar a dois**: conecte dois controles, vá em "Jogar a dois", o Jogador 2 aperta A/✕.
5. **Onde fica meu save** (Windows/Linux/modo portátil) + como fazer backup/exportar.
6. **Coloque seus próprios carros**: link para `docs/guias/adicionar-carro.md` e para o download do **S-Senna Studio** + add-on do Blender.
7. **Rodar do código-fonte**: instalar Godot (versão do `.godot-version`), `git lfs install`, `git clone`, `tools/scripts/jogar.bat`.
8. **Problemas comuns**: controle não reconhecido (Steam Input, cabo/bluetooth, testar na tela de controles), tela preta/GPU antiga (modo leve), FPS baixo (presets), antivírus.
9. **Contribuir** (link `CONTRIBUTING.md`), **Créditos** e **Licença** (código MIT; arte conforme `LICENSE-ASSETS.md`).

## Tarefas
1. Revisar presets de exportação (ícone do app, nome do produto, versão, `embed_pck` desligado, filtros).
2. Ícone do jogo e do Studio (`.ico`/`.png`) com arte própria.
3. Workflow de release com cache de LFS e de Godot; checkout **com LFS** só aqui.
4. Script de *smoke test* da build: abrir o executável exportado em headless por alguns segundos (carregar conteúdo e uma pista) e checar o log.
5. README e `LEIA-ME.txt`; capturas e GIF (gravados com OBS pelo dono ou gerados pelo Movie Maker do Godot).
6. `CHANGELOG.md` com a 1.0; política de versões (SemVer; saves compatíveis dentro da mesma major ou migrados).
7. Checklist de release em `docs/guias/como-lancar-versao.md`.

## Critérios de aceite
### 🤖 Automáticos
- [ ] Tag `v0.x.0-teste` gera Release com 4 zips + checksums.
- [ ] Smoke test das builds passa no CI.
- [ ] Links do README válidos (checagem de links no CI).
### 🎮 Manuais
- [ ] Alguém que nunca viu o projeto baixa, extrai e joga (inclusive a dois) só lendo o README.
- [ ] Build roda num PC "limpo" com Windows 10/11.

## Fora do escopo
Assinatura de código, lojas (Steam etc.).
