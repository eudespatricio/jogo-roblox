# CONTINUAR — handoff de sessão

**Data:** 09/11/2026 · **Status:** pré-P0, nenhum código de produção · base `main` (sem hash fixo; veja `git log -1`).
Este arquivo é autossuficiente: a conversa pode ser fechada.

---

## O que é este projeto

**MURALHA** — tower defense invertido + autobattler assíncrono para Roblox, mobile-first, sem avatar
visível (habilita DevEx 18+ e corta custo de arte). O jogador monta a muralha, outros atacam
enquanto ele está offline, e um replay determinístico de 8s mostra o que aconteceu — com botão de
gravar clipe via `CaptureService`.

Equipe: 1 humano (direção, cena, game feel, QA) + 2 agentes (motor/CI e sistemas/economia).
A divisão de tarefas **não foi executada**; a P0 **não foi autorizada**.

---

## Onde paramos

- Conceito aprovado (GDD v1.1, decisões 1–5 fechadas).
- Motor determinístico v2 portado para `src/shared/sim/` e provado em `sim/` (inteiro, 1.200 ticks,
  `mul32`/`add32`).
- Tooling: Rokit + CLI/GUI, CI ativo (runs #1–#5 verdes), estação calibrada; ProfileStore
  vendorizado; wrapper/schema na P0.
- Auditoria `context-recovery` concluída: 7 contradições resolvidas; **Q1 e Q2 fechadas**.
- Contexto residente instalado e dentro do teto.
- Monetização decidida (base 2% × US$ 2; gate líquido US$ 0,005); ProfileStore vendorizado;
  taxonomia de analytics v1 escrita.
- **P0 em andamento:** port + `sim/acceptance.luau` verdes (1.000 seeds × 3, hash `668061367`).
  **P1 não iniciada.**

---

## Migração para WSL (em andamento)

- Repo publicado: **https://github.com/eudespatricio/jogo-roblox** (branch `main`; HEAD atual no topo do git).
- No WSL, clonar em `/home/eudespatricio/jogo-roblox` e rodar `bash scripts/setup-wsl.sh`
  (instala Rokit + ferramentas, roda invariantes e `--check`, imprime o IP).
- **Rede (resolvido em 09/11/2026):** o Rojo roda no WSL escutando **`127.0.0.1:34872`** e o Windows
  alcança **`localhost:34872`** pelo encaminhamento de localhost do WSL. **Não use
  `--address 0.0.0.0`** (quebra o encaminhamento) e **não é necessário firewall**. Regras clássicas
  e do Hyper-V são inócuas em modo NAT (`NATInboundRuleNotApplicable`).
- Teste feito: `rojo serve` no WSL + `http://localhost:34872/api/rojo` → **HTTP 200** no Windows.
- Se um dia precisar de acesso da LAN, aí sim portproxy ou `networkingMode=mirrored`.
- `.tools/` é binário Windows e não é versionado; no WSL as ferramentas vêm do `rokit install`.
- Se a pasta no WSL estiver vazia, o repo ainda não foi clonado — clone antes de ler o resto.

---

## Fatos (não reinventar)

| Métrica | Valor |
|---|---|
| tick / cap | 0,05 s · 1.200 ticks (60 s) |
| estado | 100% inteiro (`MILLI = 1000`) |
| custo por batalha | ~1,3 ms (~750/s) |
| determinismo | hash `668061367` (seed 42, 3 execuções) |
| 500 seeds | 500 hashes distintos · 64,8% vitória do defensor |
| P0 acceptance | 1.000 seeds × 3 · 1.000 hashes · 64,9% defensor · 1,5s/1.000 |
| invariantes | **10/10** (`sim/invariants.luau`) |
| contexto residente | ESTADO 70/80 · MAPA 51/60 · REJEITADOS 17/40 |
| monetização | base 2% × US$ 2 · topo 4,5% × US$ 5 · gate ARPDAU líquido US$ 0,005 |
| Q2 | 5×5, N=5 ativas, colocação livre (09/11/2026) |
| Q1 | apagar o legado na P1, preservando `src/shared/sim/` (09/11/2026) |

---

## Pesquisa de apoio a Q1/Q2 (fechadas)

`docs/pesquisa-grade-e-prototipo.md` levanta a evidência para as duas perguntas:

- **Q2 (fechada em 09/11/2026):** 5×5 com **N=5 armadilhas ativas** e colocação livre → C(25,5) =
  53.130 layouts; 25 simultâneas seria fora da curva. O A/B de 20–30 jogadores (§5) vira fallback
  de playtest, não pré-requisito.
- **Q1 (fechada em 09/11/2026):** apagar o legado de moedas na P1, preservando `src/shared/sim/`,
  com tag `legacy-coins`, stub de 10 linhas e `rojo build` no CI.

Q1 e Q2 foram decididas em 09/11/2026; nenhuma pergunta aberta.

---

## Pesquisa de monetização (09/11/2026)

`docs/pesquisa-monetizacao.md` confronta as premissas de receita com o mercado:

- Os TDs do topo examinados vendem **poder e sorte**; cosmético é complemento: torres 168–1.574 R$,
  passe 399–499, cosmético 55–360.
- O modelo usava 4% × US$ 5 — cenário de topo. A base de planejamento agora é **2% × US$ 2**;
  o relatório mede 3,8% que pagaram algo em 12 meses, não por mês.
- Gate resolvido em 09/11/2026: **ARPDAU líquido ≥ US$ 0,005** (bruto ≈ 0,0225; ~BRL 20 mil/mês a
  25 mil DAU). O "Negócio" (4,5% × US$ 5) passa com 0,0083 líquido.
- Canais melhores: assinatura em moeda local (100% após o 1º mês), Roblox Plus (78–88% + 750 R$ por
  signup), regional pricing automático.
- Preços do GDD seguem em aberto; a decisão de premissas/gate está em
  [`decisao-monetizacao.md`](decisao-monetizacao.md).

---

## Revisão de direção (09/11/2026)

`docs/revisao-direcao.md` responde ao pedido original ("a vida depende dessa receita"):

- Engenharia e design: **no caminho certo**. Produto e receita: **não provados**.
- O cenário "Negócio" é TD de porte médio com **monetização de topo** — a combinação mais difícil.
- Com premissas base (22,2% líquido), BRL 10 mil/mês exige ~42 mil DAU; BRL 50 mil, ~209 mil. Não é plano de lançamento.
- Recomendação: **teste de produto de 3 semanas (US$ 300–500) antes da P0**, com critérios de kill
  definidos (entendimento, diversão, oferta, D1, CTR).
- Não pivotar sem dados; não construir mais motor antes do teste.

---

## Ferramentas (09/11/2026)

`docs/ferramentas.md` audita o que existe e o que falta para qualidade de ponta:

- **Existe:** Studio + Rojo plugin; Rokit (Rojo/StyLua/Selene/Luau); Blender 4.5.15 LTS
  (`blender4.5`) e 4.2 (`blender`) com Cycles CUDA (RTX 3060); WSLg; Python 3.14.
- **Instalado em 09/11/2026:** git-lfs 3.8.1, luau-lsp 1.70.1, Lune 0.11.1, Pesde 0.7.4,
  rbxcloud 0.17.0, oxipng 10.2.1, Blender 4.5.15 LTS; ffmpeg 7.0.2; Krita/Inkscape/Audacity/
  ImageMagick/pngquant/optipng/OBS.
- **Pronto:** `scripts/doctor.sh` (estação completa), `scripts/check.sh` (gate), CI ativo
  (CI ativo; primeiros runs verdes), `.luaurc` strict, `.vscode/settings.json`, LFS com exceção `assets/models`,
  calibração `art/calibration.blend` + `calibration.glb/fbx`.
- **Calibração:** importada no Studio; o importador glTF do Studio perde a cor base (cinza) e
  espelha o rótulo de face única — cosmético, documentado em `art/README.md`; reimportar no Blender
  mostra tudo correto.
- **Falta:** wrapper/schema v1 do ProfileStore (P0), primeiro asset real; Selene segue bloqueado
  (parser não aceita `+=`), lint é `luau-lsp`. ProfileStore vendorizado em `vendor/`.
- **Pipeline 3D:** Blender (WSL) → glTF/FBX → Studio 3D Importer → `.rbxm` versionado (LFS) → Rojo.
- **Atenção:** `.gitignore` ignora `*.rbxm`, com exceção em `assets/models`; shell não-login não acha
  `rojo`/`blender`/`git-lfs` — use `source scripts/env.sh`.
- **Manual operacional:** `docs/estacao-de-trabalho.md`.

---

## Decisões fechadas: Q1 e Q2

| # | Decisão | Registro |
|---|---|---|
| **Q2** | Grade 5×5, **N=5 armadilhas ativas**, colocação livre nas 25 células | GDD, decisão 1 |
| **Q1** | **Apagar o legado de moedas na P1**, preservando `src/shared/sim/`; tag `legacy-coins` + stub de 10 linhas + `rojo build` no CI | `.context/REJEITADOS.md` |

Q1 e Q2 foram fechadas em 09/11/2026. `docs/auditoria/CONTRADICOES.md` foi apagado. A remoção do
legado é P1 — não foi executada agora.

**Próximo passo:** concluir a P0 — schema v1 + ProfileStore, contrato de analytics e teste de
sessão no Studio. A taxonomia v1 está em `docs/taxonomia-analytics.md`; o teste de 3 semanas
continua antes da P1.

---

## O que está documentado

| Arquivo | O que é |
|---|---|
| `docs/gdd-muralha.md` | GDD v1.1: loop, drop-in, modos, economia, fases, decisões |
| `docs/spec-motor-deterministico.md` | motor, replay, clipe/CaptureService, anti-cheat, auditorias |
| `docs/padroes-engenharia.md` | regras com fonte oficial + tooling + CI |
| `docs/pesquisa-tendencias-2026.md` | mercado, gêneros, algoritmo |
| `docs/pesquisa-jogadores.md` | reclamações/pedidos + 10 regras |
| `docs/tese-produto-e-economia.md` + `docs/modelo-financeiro.xlsx` | economia unitária |
| `docs/referencias-tower-defense.md` | jogos/vídeos para estudar |
| `docs/pesquisa-grade-e-prototipo.md` | evidência e decisão de Q1/Q2 (fechadas) |
| `docs/pesquisa-monetizacao.md` | preços, benchmarks e canais de receita |
| `docs/revisao-direcao.md` | veredito de rota e teste de 3 semanas pré-P0 |
| `docs/decisao-monetizacao.md` | premissas base/topo e gate ARPDAU |
| `docs/taxonomia-analytics.md` | eventos, funil, métricas e sink |
| `vendor/ProfileStore.luau` + `SOURCE.md` | ProfileStore oficial vendorizado (Apache-2.0) |
| `docs/ferramentas.md` | toolchain auditado + pipeline Blender→Studio |
| `docs/estacao-de-trabalho.md` | manual operacional da estação + doctor |
| `src/shared/sim/core.luau` · `sim/poc.luau` · `sim/invariants.luau` · `sim/acceptance.luau` | motor, benchmark, oráculo, P0 |
| `.context/ESTADO|MAPA|REJEITADOS.md` | contexto residente com teto |
| `skills/context-recovery/` | protocolo de auditoria + scanner + templates |

---

## Regras invioláveis

1. **Não iniciar P0/P1 sem autorização explícita do diretor.**
2. `src/**` é legado; não é base do jogo novo.
3. Depois de editar `src/shared/sim/core.luau`, rodar `sim/invariants.luau` e `sim/acceptance.luau`.
4. Mudou a matemática → subir `simVersion` e registrar na spec.
5. `bit32` só recebe `[0, 2^32)`: usar `add32`/`mul32`.
6. Contexto residente tem teto (80/60/40); `--check` falha se estourar.
7. Invariante não vira markdown: vira teste ou vira pergunta.
8. Não reabrir `REJEITADOS.md` sem a condição objetiva listada.

---

## Achados que não podem se perder

1. **`bit32.band` com double > 2^32 retorna lixo** (`band(7,2e16) = 1473511424`), não módulo.
2. **Aftman está arquivado** (último push 2025-07-09); Rokit é o sucessor ativo.
3. **ProfileStore** cobre crash de servidor, `Mock` e roubo de sessão — não escrever o nosso.
4. **A Video Captures API só grava para frente** (30s); o pedido do jogador é o passado — nosso
   replay por seed é a vantagem competitiva.
5. **O `mul32` antigo não errava resultado neste build**; era violação de faixa (risco de
   portabilidade). Corrigido como endurecimento, não como bugfix.
6. **O invariante I6 falhou primeiro porque o teste estava errado** (muralha morria antes do cap),
   não o código. Consertamos o teste.
7. **O README descrevia o jogo de moedas** — doc mais velho que código mente; a radiografia pegou.

---

## Como retomar

Cole na nova sessão:

> Você está no repositório `jogo-roblox` (projeto MURALHA, P0 em andamento). Leia `AGENTS.md`,
> `.context/ESTADO.md`, `.context/MAPA.md` e `CONTINUAR.md`. No WSL: `source scripts/env.sh`,
> `bash scripts/doctor.sh` e `bash scripts/check.sh` (devem passar). Não inicie P1. A P0 já tem o
> motor portado e o `sim/acceptance.luau` verde; faltam schema/ProfileStore, contrato de analytics
> e teste no Studio. O teste de produto de 3 semanas continua antes da P1. Q1 e Q2 estão fechadas:
> Q2 = 5×5 com N=5 ativas; Q1 = apagar o legado na P1, preservando `src/shared/sim/`.
