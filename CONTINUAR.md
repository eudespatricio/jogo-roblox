# CONTINUAR — handoff de sessão

**Data:** 09/11/2026 · **Status:** P0 fechada; **P1 autorizada** para a próxima janela · base `main`.
Este arquivo é autossuficiente: a conversa pode ser fechada.

---

## O que é este projeto

**MURALHA** — tower defense invertido + autobattler assíncrono para Roblox, mobile-first, sem avatar
visível (habilita DevEx 18+ e corta custo de arte). O jogador monta a muralha, outros atacam
enquanto ele está offline, e um replay determinístico de 8s mostra o que aconteceu — com botão de
gravar clipe via `CaptureService`.

Equipe: 1 humano (direção, cena, game feel, QA) + 2 agentes (motor/CI e sistemas/economia).
A P0 foi autorizada em 09/11/2026 e está **fechada**; o teste de sessão passou no Modo A (Mock)
e no Modo B (DataStore real, entre servidores). A **P1 foi autorizada** na mesma data —
plano em `docs/p1-plano.md`.

---

## Onde paramos

- Conceito aprovado (GDD v1.1, decisões 1–5 fechadas).
- Motor determinístico v2 portado para `src/shared/sim/` e provado em `sim/` (inteiro, 1.200 ticks,
  `mul32`/`add32`).
- Tooling: Rokit + CLI/GUI, CI ativo (runs #1–#5 verdes), estação calibrada; ProfileStore
  vendorizado; wrapper e schema v1 entregues na P0.
- Auditoria `context-recovery` concluída: 7 contradições resolvidas; **Q1 e Q2 fechadas**.
- Contexto residente instalado e dentro do teto.
- Monetização decidida (base 2% × US$ 2; gate líquido US$ 0,005); ProfileStore vendorizado;
  taxonomia de analytics v1 aprovada e validada no CI.
- **P0 fechada (09/11/2026):** motor, schema v1 + wrapper ProfileStore, contrato de analytics,
  gates no CI e teste de sessão aprovado nos Modos A (Mock) e B (DataStore real), 8/8 nas
  duas — evidência em `docs/teste-sessao-studio.md` §8.
- **P1 autorizada em 09/11/2026** (plano em `docs/p1-plano.md`); nenhuma fatia da P1 foi
  executada ainda.

---

## Entrega desta janela (P0, 09/11/2026)

| # | Entrega | Arquivos |
|---|---|---|
| 1 | Schema v1 + wrapper ProfileStore | `src/shared/data/ProfileSchema.luau`, `src/server/data/ProfileService.luau`, `src/server/ProfileBoot.server.luau` |
| 2 | Contrato de analytics | `src/shared/analytics/AnalyticsTypes.luau`, `sim/analytics-contract.luau` |
| 3 | Teste de sessão no Studio | `docs/teste-sessao-studio.md` + self-test em `ProfileBoot` (atributos `ProfileStoreMock`/`ProfileSelfTest`) |
| 4 | Fechamento | `sim/profile-contract.luau`, `sim/fixtures/profile-v0.luau`, `scripts/check.sh`, spec §14, ESTADO/MAPA |

Decisões e armadilhas novas:

- Store do perfil = **`MuralhaProfile_v1`**, separado do `PlayerData_v1` do protótipo de moedas
  (que morre na P1 com a tag `legacy-coins`).
- `ProfileService` é puro e recebe o store por injeção: o contrato roda no CLI com store fake,
  sem DataStore. A ligação com `Players` ficou em `ProfileBoot.server.luau`.
- `BattleResult` ganhou `seed` e `simVersion` (metadados); hash `668061367` intacto e
  `simVersion` segue **1** — nenhuma mudança de matemática nesta janela.
- `EndSession` do ProfileStore só libera o lock **depois do save**: reabrir sessão exige espera;
  o controller tenta 3× com backoff 0,5/1s.
- `ProfileStore.Mock` não persiste entre servidores: persistência real é o Modo B do roteiro
  (lugar publicado + API Services).

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
| contexto residente | ESTADO 75/80 · MAPA 57/60 · REJEITADOS 17/40 |
| monetização | base 2% × US$ 2 · topo 4,5% × US$ 5 · gate ARPDAU líquido US$ 0,005 |
| Q2 | 5×5, N=5 ativas, colocação livre (09/11/2026) |
| Q1 | apagar o legado na P1, preservando `src/shared/sim/` (09/11/2026) |
| contratos P0 | perfil 19/19 · analytics 16/16 (`sim/*-contract.luau`) |
| schema do perfil | v1 · store `MuralhaProfile_v1` · migração 0→1 com fixture |
| teste de sessão | Modo A (Mock) 8/8 + Modo B (DataStore real) 8/8 · 09/11/2026 |

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
- **Falta:** primeiro asset real; sink de analytics (`AnalyticsService`, P1); Selene segue
  bloqueado (parser não aceita `+=`), lint é `luau-lsp`. ProfileStore vendorizado em `vendor/`;
  wrapper/schema v1 feitos na P0.
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

**Próximo passo:** P1 autorizada em 09/11/2026; S1 = Q1 (tag `legacy-coins`, deleção do
legado, stub). O teste de 3 semanas segue recomendado e roda em paralelo
(`docs/p1-plano.md` §6).

## P0 — fechamento (09/11/2026)

| # | Entrega | Onde | Status |
|---|---|---|---|
| 1 | **Schema v1 + wrapper ProfileStore** | `src/shared/data/ProfileSchema.luau` · `src/server/data/ProfileService.luau` · `src/server/ProfileBoot.server.luau` | **feito** — contrato 19/19 |
| 2 | **Contrato de analytics** | `src/shared/analytics/AnalyticsTypes.luau` · `sim/analytics-contract.luau` | **feito** — 31 eventos, 16/16 |
| 3 | **Teste de sessão no Studio** | `docs/teste-sessao-studio.md` + self-test no boot | **feito** — Modos A e B, 8/8 (09/11/2026) |
| 4 | **Fechamento** | spec §14, ESTADO, MAPA, CONTINUAR, `scripts/check.sh` | **feito** |

Provado no CI (headless):
- `sim/profile-contract.luau`: template, validação, migração 0→1 com fixture, `StartSessionAsync`
  nil com backoff, `EndSession` no leave, recarga sem duplicar, versão futura recusada.
- `sim/analytics-contract.luau`: envelope/catálogo/limites/PII e `battle_finished` montado do
  `BattleResult` sem alterar o hash `668061367`.
- `check.sh` passou a analisar `src/shared/data`, `src/shared/analytics` e `src/server/data`, e roda
  os dois contratos.

**Item 3 aprovado:** Modos A (Mock) e B (DataStore real) passaram 8/8 em 09/11/2026 (§8 e
§8.1). O Modo B provou persistência entre servidores: `sessions=3` no segundo Play.

**Não entra na P0:** cena 5×5, UI, loja, drop-in/raid/replay (P1); remoção do legado (Q1, P1);
sink de analytics (`AnalyticsService`, P1).

**Decisões que o handover herda:** Q2 = 5×5, N=5, colocação livre; Q1 = apagar o legado na P1, tag
`legacy-coins`; monetização = base 2% × US$ 2, gate líquido US$ 0,005; ProfileStore vendorizado
(Apache-2.0); store do perfil = `MuralhaProfile_v1`; taxonomia v1 congelada.

**Armadilhas:** não editar `vendor/ProfileStore.luau`; ProfileStore é server-only
(`ServerStorage.Vendor.ProfileStore`); `StartSessionAsync` pode retornar nil; `OnLastSave` pode não
disparar; o CI headless não cobre DataStore — o teste de sessão é manual no Studio; `BattleResult`
com campo novo não altera o hash; `simVersion` segue 1 até a S2 (loadout muda a matemática); `bit32` só
`[0, 2^32)`; `EndSession` libera o lock apenas depois do save.

---

## P1 — autorização e plano (09/11/2026)

**Autorizada pelo diretor em 09/11/2026.** Ordem, critério de pronto por fatia, riscos e fora de
escopo estão em [`docs/p1-plano.md`](docs/p1-plano.md) — leia antes de codar.

| # | Fatia | Critério de pronto (resumo) |
|---|---|---|
| S1 | **Q1 — apagar o legado** | tag `legacy-coins` **antes** da deleção; `check.sh`/CI verdes; `src/shared/{sim,data,analytics}` + `src/server/{data,ProfileBoot}` intactos |
| S2 | **Motor com loadout 5×5/N=5** | `simVersion 2` + hash novo + invariants/acceptance re-ancorados |
| S3 | **Muralha e economia** | célula/6ª armadilha/ouro insuficiente recusados; perfil persistido; eventos válidos |
| S4 | **Cena 5×5 + build** | build ≤ 30s; 45+ FPS mobile |
| S5 | **Drop-in de 5s** | `dropin_pressed` ≥ 60% |
| S6 | **Raid + replay 8s** | `result_hash` do replay igual ao servidor; recompensa idempotente por `battle_id` |
| S7 | **Telemetria** | contrato v1 valida 100%; nenhum evento altera `BattleResult` |

Critério de saída da P1 (GDD §10): **70% de primeira vitória em menos de 60s**, medido com
`first_win_seconds` da S7.

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
| `docs/revisao-direcao.md` | veredito de rota e teste de 3 semanas (recomendado; roda em paralelo à P1) |
| `docs/decisao-monetizacao.md` | premissas base/topo e gate ARPDAU |
| `docs/taxonomia-analytics.md` | eventos, funil, métricas e sink (v1 aprovada) |
| `docs/p1-plano.md` | P1: fatias S1–S7, critérios de pronto, riscos e fora de escopo |
| `docs/teste-sessao-studio.md` | roteiro do teste de sessão no Studio (P0) |
| `src/shared/data/ProfileSchema.luau` · `src/server/data/ProfileService.luau` | schema v1 e sessão do perfil |
| `src/shared/analytics/AnalyticsTypes.luau` · `sim/analytics-contract.luau` | contrato de analytics v1 |
| `vendor/ProfileStore.luau` + `SOURCE.md` | ProfileStore oficial vendorizado (Apache-2.0) |
| `docs/ferramentas.md` | toolchain auditado + pipeline Blender→Studio |
| `docs/estacao-de-trabalho.md` | manual operacional da estação + doctor |
| `src/shared/sim/core.luau` · `sim/poc.luau` · `sim/invariants.luau` · `sim/acceptance.luau` | motor, benchmark, oráculo, P0 |
| `.context/ESTADO|MAPA|REJEITADOS.md` | contexto residente com teto |
| `skills/context-recovery/` | protocolo de auditoria + scanner + templates |

---

## Regras invioláveis

1. **P1 autorizada em 09/11/2026; P2+ só com autorização explícita do diretor.**
2. `src/**` é legado, exceto a produção (`src/shared/{sim,data,analytics}`, `src/server/data`
   e `src/server/ProfileBoot.server.luau`); não é base do jogo novo.
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
8. **`#` em tabela de chave string não conta itens.** O teto de `cells`/`cosmetics` da migração
   nunca disparava; quem pegou foi o `luau-lsp` (`Using '#' on a table with string keys`).
9. **`EndSession` só solta o lock depois do save.** Reabrir sessão no mesmo servidor logo depois
   exige espera/retry; senão `StartSessionAsync` lança "already loaded in this session".
10. **`ProfileStore.Mock` não persiste entre servidores.** Play Solo reinicia o mock: persistência
    real precisa de lugar publicado + API Services (Modo B do roteiro).
11. **O legado quebra no Studio sem lugar publicado** (`Main`/`DataService`: "You must publish
    this place…"). É ruído esperado do protótipo de moedas, não da P0; morre na P1 (Q1).
12. **O motor da P0 é o recorte do PoC:** `Battle.new` sorteia 1 armadilha por lane e ignora
    loadout. Loadout 5×5/N=5 é mudança de matemática (`simVersion 2`), não ajuste de parâmetro.

---

## Como retomar

Cole na nova sessão:

> Você está no repositório `jogo-roblox` (MURALHA — P0 fechada; **P1 autorizada** para esta
> janela). Leia `AGENTS.md`, `.context/ESTADO.md`, `.context/MAPA.md`, `CONTINUAR.md` e **`docs/p1-plano.md`**.
> No WSL: `source scripts/env.sh`, `bash scripts/doctor.sh` e `bash scripts/check.sh` (devem passar).
> Comece pela **S1 (Q1)**: tag anotada `legacy-coins` no HEAD atual, apagar o legado de moedas
> (`CoinService`, `DataService`, `Main`, `Config`, `Hud`), stub de 10 linhas e `.styluaignore` —
> preservando `src/shared/{sim,data,analytics}` e `src/server/{data,ProfileBoot.server}`. Depois **S2**
> (motor com loadout 5×5/N=5): `simVersion 2`, hash de referência novo, invariants/acceptance
> re-ancorados. Não edite `vendor/ProfileStore.luau`; Q2 = 5×5, N=5, colocação livre; taxonomia v1
> congelada. O teste de produto de 3 semanas roda em paralelo.
