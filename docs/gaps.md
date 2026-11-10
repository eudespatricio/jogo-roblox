# GAPS — lacunas conhecidas entre P's e S's

> **Convenção:** toda fase P ou fatia S fecha com **uma linha** `GAP:` no handoff
> (`CONTINUAR.md`). Gap aberto vira **uma linha** nesta tabela, com gatilho objetivo para fechar.
> Sem gatilho, a linha não entra. Ver `docs/pipeline-expansao.md` §7.

**Linha atual:**

```text
GAP: GAP-004, GAP-005, GAP-008 · classes/taxonomia v2 e live ops ainda abertos · risco alto para a 1ª expansão real/P2 · fechar antes de classe/P2 · ver docs/gaps.md
```

| ID | Fase | Gap | Risco | Gatilho para fechar | Status |
|---|---|---|---|---|---|
| GAP-001 | S3.1 | `TrapCatalog.CONTENT_VERSION` não é persistido no perfil nem no `BattleLog`; não há gate de versão entre servidores antigo/novo | alto — perfil escrito com conteúdo novo pode travar em servidor antigo; replay não prova a versão do conteúdo | antes do primeiro tipo/classe novo em produção | fechado no perfil em 10/11/2026 · `contentVersion` + gate; `BattleLog` virou GAP-011 |
| GAP-002 | S3.1 | sem migração/repair para `trap_id` renomeado ou removido; `WallService.validateWall` falha fechado e pode trancar o jogador | alto — renomear/remover conteúdo vira lockout; a única saída hoje é migração manual | antes de qualquer rename/remove de trap | fechado em 10/11/2026 · `TRAP_ALIASES` (`oil → tar`) + `sim/content-contract.luau` |
| GAP-003 | S3.1 | stats do motor continuam hardcoded em `Core.TRAP`/`TRAP_NAMES`; tipo novo exige editar motor + decidir `simVersion`; 5º tipo do GDD não existe no motor | alto — cada expansão de conteúdo vira mudança de motor e re-ancoragem de hash | antes de escalar conteúdo além dos 4 tipos / antes do 5º tipo | fechado em 10/11/2026 · 5º tipo (`catapult`) + política explícita `SIM_VERSION++`/contrato |
| GAP-004 | S3.1 | `Cell` só tem `trap` e `level`; classe, raridade e trait não existem no schema nem no motor | médio — a primeira feature de classe exige schema v2 + migração + replay | quando classe/trait entrar no roadmap | aberto |
| GAP-005 | P2 | sem sistema de eventos/feature flags/calendário; atualização semanal e evento sazonal dependem de deploy de código | alto — live ops sem cadência; risco de update quebrar servidor em produção | antes do primeiro evento semanal/sazonal | aberto |
| GAP-006 | S4 | a guarda de perfil só roda se o servidor usar `WallService`; não há helper `toBattleWall` que force a validação antes de `Battle.new` | médio — S4/S6 podem montar `wall.traps` direto e furar a guarda | revisão de código da S4 / antes de ligar UI de build | fechado em 10/11/2026 · `42187a5` · `toBattleWall` + 13/13 (`sim/walls-contract.luau`) |
| GAP-007 | S3.2 (trial) | docs podem ficar velhas sem o CI reclamar: o `check.sh` passou verde com labels “schema v1/motor v2” e spec antiga | alto — doc mais velho que código mente e contamina a próxima janela | antes de qualquer expansão real; revisar labels e criar check de versão nos docs | fechado em 10/11/2026 · `42187a5` · `scripts/check-versions.py` + `docs/versoes.md` |
| GAP-008 | S3.2 (trial) | `trap_placed`/`upgrade_bought` não carregam class/trait/rarity; a taxonomia v1 é congelada | médio — live ops e funil não conseguem segmentar variantes | quando variantes forem para produção (taxonomia v2) | aberto |
| GAP-009 | S3.2 (trial) | schema v2 não foi testado em ProfileStore/Studio real; `STORE_NAME` continua `MuralhaProfile_v1` com `schemaVersion=2` | alto — Reconcile/DataStore real pode se comportar diferente do store fake | antes do deploy de schema v2 | fechado em 10/11/2026 · Modo B DataStore real: `schema=v2 content=v2`, sessions 11→12, selftest 8/8 |
| GAP-010 | S3.2 (trial) | default de migração neutro não é garantido por teste; um default com bônus mudaria o hash sem ninguém ver | alto — migração silenciosa buffa/nerfa muralhas antigas | em toda migração de conteúdo; teste de hash antigo x migrado | fechado em 10/11/2026 · schema v2 + `sim/content-contract.luau`/`neutral-migration.luau` |
| GAP-011 | S6 | `BattleLog` não existia/persistia `contentVersion`; replay de conteúdo futuro não tinha gate no log | médio — replay podia simular conteúdo que o servidor não conhece | na S6, junto do `BattleLog`, antes de conteúdo em produção | fechado em 10/11/2026 · `BattleLog`/`RaidController` + `contentVersion` e `isReplayable` (`sim/raid-contract.luau`) |

## Como fechar um gap

1. O gatilho da tabela é objetivo; se não chegou, o gap fica aberto (não vira tarefa solta).
2. Ao fechar, atualizar a linha para `fechado em <data> · <commit/PR>` e registrar o teste que prova.
3. Se o gap mudar de forma, criar novo ID e apontar o antigo como `substituído por GAP-xxx`.
4. O `CONTINUAR.md` da janela seguinte carrega a linha `GAP:` atualizada.

## Fechamento antes da S4 — S3.3 executada (10/11/2026)

**Resultado:** a janela **S3.3** fechou GAP-006 e GAP-007 e preparou GAP-010. A tabela abaixo é o
estado da S3.3; a **S3.4** (seção seguinte) fechou GAP-001/002/003/009/010. Os demais gaps são de
conteúdo/feature/P2 e não bloqueiam a cena/build.

| GAP | Status | Trabalho | Prova |
|---|---|---|---|
| GAP-006 | **fechado** | `WallService.toBattleWall(profile, schema, catalog, hp)` valida, ordena e converte `cells` em `wall.traps`; S4 usa só esse helper | perfil válido/inválido, ordem determinística e hash igual em `sim/walls-contract.luau` (13/13) |
| GAP-007 | **fechado** | `scripts/check-versions.py` no `check.sh` compara `SCHEMA_VERSION`, `CONTENT_VERSION`, `SIM_VERSION` e hash com `docs/versoes.md`; labels saem da fonte | divergência simulada falha; versão atual passa |
| GAP-010 | **preparado** | `tools/expansion-test/neutral-migration.luau` compara hash da parede antiga x migrada; roda no `check.sh` para 0→1 | fecha de fato no primeiro schema v2 |
| GAP-009 | **fechado na S3.4** | Modo B schema v2 no ProfileStore/DataStore real | `schema=v2 content=v2`, 8/8 (10/11/2026) |
| GAP-001 | não | `contentVersion` no perfil + `BattleLog` | fatia de conteúdo; parte final depende da S6 |
| GAP-002 | não | migração/repair de `trap_id` renomeado/removido | fatia de conteúdo |
| GAP-003 | não | stats do motor fora do código ou política explícita de `simVersion` por tipo | fatia de conteúdo/engine |
| GAP-004 | não | classe/trait/raridade no schema real (o trial provou o mecanismo) | feature de classe |
| GAP-008 | não | campos de variante na taxonomia v2 | feature de classe/variantes |
| GAP-005 | não | eventos/flags/calendário | P2/live ops |

**Próximo:** QA humano da S6 (scaffold da raid/BattleLog/replay). A expansão de classe/taxonomia
v2 continua bloqueada por GAP-004/008; GAP-011 fechou no `BattleLog`.

## S3.4 — conteúdo e versões (10/11/2026)

| GAP | Status | Prova |
|---|---|---|
| GAP-001 | **fechado no perfil** | `contentVersion` no schema v2 + `ensureProfileContent` no boot; `BattleLog` → GAP-011 |
| GAP-002 | **fechado** | `oil → tar` por `TRAP_ALIASES`; perfil com trap desconhecida falha fechado; `content-contract` 7/7 |
| GAP-003 | **fechado** | `catapult` (5º tipo, splash) com `SIM_VERSION 3`; política explícita no catálogo/`walls-contract` |
| GAP-010 | **fechado** | hash da parede antiga (`oil`) x migrada (`tar`) igual em `sim/content-contract.luau` e no kit |
| GAP-009 | **fechado** | Modo B DataStore real (10/11/2026): `schema=v2 content=v2`, `sessions 11→12`, `[selftest] PASSOU (8/8)`; `STORE_NAME=MuralhaProfile_v1` com schema v2 |
| GAP-011 | **fechado na S6** | `BattleLog.contentVersion` + `isReplayable`; prova em `sim/raid-contract.luau` |

## S4 — fechada (10/11/2026)

Sem gap novo e sem mudança de versão (`schema 2`, `content 2`, `sim 3`, hash `2489780106`). QA
runtime com FPS 60/60, Play→UI 1,9 s e prints 375×812/720×1280; evidência em
[`teste-s4-studio.md`](teste-s4-studio.md) §7. Nenhum GAP-004/005/008/011 mudou de estado.

## S5 — fechada (10/11/2026)

Sem gap novo e sem mudança de versão (`schema 2`, `content 2`, `sim 3`, hash `2489780106`). A S5
entrega cena/DEFENDER, timeout/retry, `dropin_shown`/`dropin_pressed` como props validadas e o
**+3 ouro** no clear (`WallService.creditGold(3, "defense")`); envelope/sink é S7. A taxa ≥60% é
medida no teste de 3 semanas; QA de feature em [`teste-s5-studio.md`](teste-s5-studio.md) §8.

## S6 — scaffold + GAP-011 fechado (10/11/2026)

Sem mudança de versão (`schema 2`, `content 2`, `sim 3`, hash `2489780106`). O `BattleLog` agora
persiste `contentVersion` e `isReplayable` recusa conteúdo futuro; `sim/raid-contract.luau` prova
hash de replay, 1 chave por `battle_id` e recompensa idempotente. GAP-011 **fechado**; QA humano da
raid pendente em [`teste-s6-studio.md`](teste-s6-studio.md) §7.
