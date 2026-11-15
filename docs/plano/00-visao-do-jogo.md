# 00 — Visão do Jogo

> **S-Senna** (nome provisório) é um jogo de corrida arcade para PC, com visual "PS2+", focado em
> **colecionar e customizar carros** e em **jogar a dois no mesmo PC**, cada um com seu controle.

---

## 1. A ideia em uma frase

Pegar a alma de *Need for Speed Underground 1 e 2*, *Most Wanted* e *Midnight Club 3: DUB Edition Remix*
(noite, neon, bodykits, rodas, vinis, sensação de velocidade) e juntar com o que esses jogos não tinham no PC:
**tela dividida para dois jogadores** e **um jeito fácil de colocar seus próprios carros no jogo**.

## 2. Pilares (o que nunca pode ser sacrificado)

| # | Pilar | O que significa na prática |
|---|-------|----------------------------|
| 1 | **Garagem de colecionador** | O dono coloca no jogo os carros das miniaturas que coleciona. Adicionar um carro novo tem que ser um processo guiado e repetível, não um projeto heroico. |
| 2 | **Customização visual profunda** | Muita variedade de bodykits, rodas, pinturas, vinis, neon e stance. É o coração do jogo. |
| 3 | **Performance simples** | Upgrades em níveis e poucos ajustes. Ninguém precisa entender de relação de marchas para ter um carro rápido, forte e fácil de pilotar. |
| 4 | **Dois jogadores no mesmo PC** | Tela dividida com 2 controles desde cedo no desenvolvimento, não como "extra" no final. |
| 5 | **Leve e bonito** | Visual inspirado na geração PS2, com iluminação e reflexos modernos onde custam pouco. Roda em PC modesto, mesmo com tela dividida. |
| 6 | **Aberto** | Repositório público, README fácil, qualquer pessoa pode baixar, jogar e criar seus próprios pacotes de carros. |

## 3. O que pegar de cada referência

| Referência | O que inspira no S-Senna | O que **não** vamos copiar |
|---|---|---|
| **NFS Underground 1** | Corridas noturnas na cidade, modos Circuito / Sprint / Drag / Drift, visual molhado e neon. | Nomes, músicas, logos, pistas e arte do jogo. |
| **NFS Underground 2** | Profundidade da customização visual (vinis em camadas, neon, peças por categoria), "nota visual" do carro. | Lojas espalhadas pelo mapa (vamos usar garagem única). |
| **NFS Most Wanted** | Carreira com rivais em escada (subir no ranking derrotando "chefes"). | Polícia e perseguições (fora do escopo da 1.0). |
| **Midnight Club 3 Remix** | **Garagem única** com tudo dentro (concessionária + visual + performance), sensação de velocidade, cidade viva. | Mundo aberto (fica para depois da 1.0). |

> Regra de ouro: inspirar-se em **mecânicas e sensações**, nunca copiar conteúdo (nomes, arte, músicas, mapas).

## 4. Os dois "loops" do projeto

### 4.1 Loop do jogador
```
Garagem ──► escolhe evento no mapa ──► corre (sozinho ou a dois)
   ▲                                          │
   │                                          ▼
customiza / compra ◄── desbloqueia peças ◄── ganha dinheiro + reputação
```

### 4.2 Loop do criador (o dono do projeto adicionando a coleção)
```
Miniatura na estante
  └► fotos + dimensões reais do carro
      └► Blender + add-on "S-Senna CarKit" (modelar/organizar/validar/exportar)
          └► S-Senna Studio (dados, rodas, som, preço, foto da vitrine, test drive)
              └► carro aparece na Concessionária do jogo
```
Esse segundo loop é **tão importante quanto o primeiro**. As etapas 03, 05 e 06 existem para que ele seja rápido.

## 5. Escopo

### 5.1 Dentro da versão 1.0
- Garagem única estilo Midnight Club: Concessionária, Meus Carros, Visual, Performance, Coleção, Fotos.
- Customização visual: bodykits por carro + peças universais, rodas (tamanho, tala, offset, cambagem), pintura
  com vários acabamentos, vinis em camadas, vidros, faróis, neon, placa, altura.
- Performance em níveis (Rua / Pro / Elite) + poucos ajustes + botão "deixar no máximo".
- 2 pistas: **Campo de Provas** (testes, dia) e **Centro** (circuito urbano à noite), com vários traçados cada.
- Modos: Circuito, Sprint, Drag, Drift, Contra o Relógio.
- IA adversária simples e divertida.
- **Tela dividida para 2 jogadores** com 2 controles (ou controle + teclado).
- Carreira curta com história leve (mensagens, rivais, capítulos).
- Sistema de save local com perfis, backups automáticos e modo portátil.
- **S-Senna Studio**: aplicativo separado para adicionar carros, peças, rodas e vinis.
- Add-on do Blender para preparar os modelos.
- Builds para Windows e Linux no GitHub Releases.

### 5.2 Fora do escopo da 1.0 (pode vir depois)
- Mundo aberto, tráfego, polícia.
- Multiplayer online (dica: *Steam Remote Play Together* e *Parsec* já permitem jogar a tela dividida pela internet sem programar nada).
- Danos visuais na carroceria.
- Interior detalhado / câmera de cockpit completa.
- Volantes com force feedback (podem funcionar como controle comum, sem garantia).
- Consoles.

## 6. Plataforma e público
- **PC Windows 10/11** (principal) e **Linux**. macOS opcional (sem assinatura de app).
- Controles: Xbox, PlayStation (DualShock 4 / DualSense), Switch Pro e genéricos (suporte via SDL3, embutido no Godot 4.5+).
- Teclado também funciona (inclusive dois jogadores no mesmo teclado, como último recurso).

### Requisitos-alvo (para guiar decisões de desempenho)
| Perfil | Hardware de referência | Meta |
|---|---|---|
| Mínimo | GPU integrada recente (Intel Iris Xe / Radeon Vega 8), 8 GB RAM | 720p, 60 FPS sozinho, 30+ FPS em tela dividida (preset Baixo) |
| Recomendado | GTX 1060 / RX 580 ou melhor, 8–16 GB RAM | 1080p, 60 FPS em tela dividida (preset Alto) |

## 7. Identidade visual (direção de arte)
- **Noite urbana**: asfalto molhado, reflexos fortes, bloom, neon, luzes de poste alaranjadas e fachadas iluminadas.
- **Carros são as estrelas**: pintura com verniz e reflexo bonito, mesmo com poucos polígonos.
- **"PS2+"**: geometria e texturas modestas como na era PS2/PS3-inicial, mas com iluminação, tonemapping e pós-processamento modernos (baratos).
- **Interface** ousada, itálica, com cores fortes — clima de revista de tuning dos anos 2000, com arte própria.

## 8. Nome
"S-Senna" é o nome do repositório e o nome provisório do jogo. 🧑 **Decisão do dono**: confirmar o nome final antes
da primeira release pública (ver observação em `05-riscos-e-questoes-legais.md`).
