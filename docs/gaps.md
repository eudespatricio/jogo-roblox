# GAPS — lacunas conhecidas entre P's e S's

> **Convenção:** toda fase P ou fatia S fecha com **uma linha** `GAP:` no handoff
> (`CONTINUAR.md`). Gap aberto vira **uma linha** nesta tabela, com gatilho objetivo para fechar.
> Sem gatilho, a linha não entra. Ver `docs/pipeline-expansao.md` §7.

**Linha atual:**

```text
GAP: GAP-005, GAP-013, GAP-018, GAP-019, GAP-020 · P2 (Waves 1 & 2) fechou GAP-004, GAP-008, GAP-015 e GAP-016 ponta a ponta (schema v3, content v3, sim v5, analytics v2, colocação livre step 250 + MOVE, muralha Nv1..5, Guia de Combos, raid 1×/2×/3× e 75 assets Open Cloud); seguem abertos live ops (GAP-005), ticket regional (GAP-013), co-op síncrono/campanha/bosses (GAP-018), F1/stems BGM (GAP-019) e sistemas comerciais (GAP-020) · ver docs/gaps.md
```

| ID | Fase | Gap | Risco | Gatilho para fechar | Status |
|---|---|---|---|---|---|
| GAP-001 | S3.1 | `TrapCatalog.CONTENT_VERSION` não é persistido no perfil nem no `BattleLog`; não há gate de versão entre servidores antigo/novo | alto — perfil escrito com conteúdo novo pode travar em servidor antigo; replay não prova a versão do conteúdo | antes do primeiro tipo/classe novo em produção | fechado no perfil em 10/11/2026 · `contentVersion` + gate; `BattleLog` virou GAP-011 |
| GAP-002 | S3.1 | sem migração/repair para `trap_id` renomeado ou removido; `WallService.validateWall` falha fechado e pode trancar o jogador | alto — renomear/remover conteúdo vira lockout; a única saída hoje é migração manual | antes de qualquer rename/remove de trap | fechado em 10/11/2026 · `TRAP_ALIASES` (`oil → tar`) + `sim/content-contract.luau` |
| GAP-003 | S3.1 | stats do motor continuam hardcoded em `Core.TRAP`/`TRAP_NAMES`; tipo novo exige editar motor + decidir `simVersion`; 5º tipo do GDD não existe no motor | alto — cada expansão de conteúdo vira mudança de motor e re-ancoragem de hash | antes de escalar conteúdo além dos 4 tipos / antes do 5º tipo | fechado em 10/11/2026 · 5º tipo (`catapult`) + política explícita `SIM_VERSION++`/contrato |
| GAP-004 | S3.1 | `Cell` só tem `trap` e `level`; classe, raridade e trait não existem no schema nem no motor | médio — a primeira feature de classe exige schema v3 + migração + replay | quando classe/trait entrar no roadmap (**spec: [`RFC-002`](rfcs-p2-e-fechamento-gaps.md#3-rfc-002--profileschema-v3-battlelog-estendido--core-v4-gap-004--gap-016)**) | fechado em 13/11/2026 · P2 Wave 1 (`ProfileSchema v3`, `x/y` step 250, `wall.level` 1..5, `activeTrapLimit` 5..7, `equipped`, migração `v2->v3`, `profile-contract` 22/22) |
| GAP-005 | P2 | sem sistema de eventos/feature flags/calendário; atualização semanal e evento sazonal dependem de deploy de código | alto — live ops sem cadência; risco de update quebrar servidor em produção | antes do primeiro evento semanal/sazonal (**spec: [`RFC-004`](rfcs-p2-e-fechamento-gaps.md#5-rfc-004--live-ops-feature-flags--calendário-sazonal-gap-005)**) | aberto |
| GAP-006 | S4 | a guarda de perfil só roda se o servidor usar `WallService`; não há helper `toBattleWall` que force a validação antes de `Battle.new` | médio — S4/S6 podem montar `wall.traps` direto e furar a guarda | revisão de código da S4 / antes de ligar UI de build | fechado em 10/11/2026 · `42187a5` · `toBattleWall` + 13/13 (`sim/walls-contract.luau`) |
| GAP-007 | S3.2 (trial) | docs podem ficar velhas sem o CI reclamar: o `check.sh` passou verde com labels “schema v1/motor v2” e spec antiga | alto — doc mais velho que código mente e contamina a próxima janela | antes de qualquer expansão real; revisar labels e criar check de versão nos docs | fechado em 10/11/2026 · `42187a5` · `scripts/check-versions.py` + `docs/versoes.md` |
| GAP-008 | S3.2 (trial) | `trap_placed`/`upgrade_bought` não carregam class/trait/rarity; a taxonomia v1 é congelada | médio — live ops e funil não conseguem segmentar variantes | quando variantes forem para produção (**spec: [`RFC-003`](rfcs-p2-e-fechamento-gaps.md#4-rfc-003--taxonomia-de-analytics-v2-gap-008)**) | fechado em 13/11/2026 · P2 Wave 1 (`AnalyticsTypes v2`, `trap_placed`/`upgrade_bought` com `x,y`, `trap_moved`, `wall_upgraded`, `cosmetic_equipped`, `sink="wall"`, `analytics-contract` 35/35) |
| GAP-009 | S3.2 (trial) | schema v2 não foi testado em ProfileStore/Studio real; `STORE_NAME` continua `MuralhaProfile_v1` com `schemaVersion=2` | alto — Reconcile/DataStore real pode se comportar diferente do store fake | antes do deploy de schema v2 | fechado em 10/11/2026 · Modo B DataStore real: `schema=v2 content=v2`, sessions 11→12, selftest 8/8 |
| GAP-010 | S3.2 (trial) | default de migração neutro não é garantido por teste; um default com bônus mudaria o hash sem ninguém ver | alto — migração silenciosa buffa/nerfa muralhas antigas | em toda migração de conteúdo; teste de hash antigo x migrado | fechado em 10/11/2026 · schema v2 + `sim/content-contract.luau`/`neutral-migration.luau` |
| GAP-011 | S6 | `BattleLog` não existia/persistia `contentVersion`; replay de conteúdo futuro não tinha gate no log | médio — replay podia simular conteúdo que o servidor não conhece | na S6, junto do `BattleLog`, antes de conteúdo em produção | fechado em 10/11/2026 · `BattleLog`/`RaidController` + `contentVersion` e `isReplayable` (`sim/raid-contract.luau`) |
| GAP-012 | S7 | `AnalyticsService` usava sink `Null`: validava e descartava; a taxa de 70% de `first_win_seconds` se perdia no leave | alto — sem persistência o gate de saída da P1 não era mensurável de verdade | antes do teste de 3 semanas / do fechamento da P1 | fechado em 10/11/2026 · `AnalyticsDataStoreSink` (`MuralhaAnalytics_v1`, DataStore/Memory) + contrato 34/34; export/retention em `teste-s7-studio.md` |
| GAP-013 | P2 | ticket médio/ARPPU por país não medido; benchmark global e ABPDAU regional; Brasil dentro do ROW | alto — preço internacional e projeção de receita podem errar | antes de P2/loja fora do BR; Creator Analytics + preço dinâmico (**spec: [`RFC-006`](rfcs-p2-e-fechamento-gaps.md#7-rfc-006--precificação-regional-dinâmica--auditoria-creator-analytics-gap-013)**) | aberto |
| GAP-014 | S6.1/S7 | `WallController` não passa `emit` ao `WallService` (`trap_placed`/`upgrade_bought`/`gold_spent` mudos), `DropInController` perde `dropin_shown` por corrida com `AnalyticsBoot`, e `RaidController` ataca `currentSnapshot` (auto-raid + duplo `UpdateAsync` em `battleId`) | alto — corrompe funil S5 (`>=60%`), oculta economia de build e permite farm infinito em parede vazia | na retomada da P1, antes de abrir tráfego do teste de 3 semanas (**runbook: [`plano-playtest-v1.md`](plano-playtest-v1.md#2-fatia-s81--loop-jogável-progressão-l1l5--gap-014)** + [`RFC-001`](rfcs-p2-e-fechamento-gaps.md#2-rfc-001--integridade-s61s7--polimento-s8ci-pré-tráfego-p1-gap-014--gap-017)) | fechado em 13/11/2026 · Playtest V1 (`WallController` emit + cooldown, `DropInController` retry + 40g único, `RaidController` + `BotPhantoms` + `PhantomStore` 8-slots + 1 write `BattleLogStore`; `dropin-contract` 11/11, `raid-contract` 13/13, `analytics-contract` 35/35) |
| GAP-015 | P2 | `MuralhaPhantom_v1` usa chave global única `"latest"` (cooldown de 6s/chave) e salva `ownerName`/`ownerId` sem sharding por liga nem metadado GDPR `AddUserId` | alto — trava acima de ~10 raids/min globais e expõe PII em DataStore sem gancho de exclusão | antes do matchmaking por liga da P2 ou >10 raids/min (**spec: [`RFC-005`](rfcs-p2-e-fechamento-gaps.md#6-rfc-005--sharding-muralhaphantom_v2-memorystoresortedmap-sem-colisão--gdpr-gap-015)**) | fechado em 13/11/2026 · P2 Wave 1 (`PhantomStore` 8 slots/liga sem PII, suporte a `level` 1..5, `hp` 500..1250 e até 7 armadilhas `{type,level,x,y,cell?}`, `BotPhantoms` Nv1..5) |
| GAP-016 | P2 | `BattleLog` não persiste `waveSpec`/cosméticos equipados, `ProfileSchema` não tem slots `equipped`, e `Core` hardcoda `slowPct=55` e `GRID_WIDTH=5` | médio — bloqueia "Montar Onda", skills/gambits, cosméticos em replay e grade 7×5 | na RFC de `schema v3` / `motor v4` para P2 (**spec: [`RFC-002`](rfcs-p2-e-fechamento-gaps.md#3-rfc-002--profileschema-v3-battlelog-estendido--core-v4-gap-004--gap-016)**) | fechado em 13/11/2026 · P2 Wave 1 (`Core v5`, `ProfileSchema.equipped`, `WallService.equipCosmetic`/`upgradeWall`, `BuildProtocol`/`GridLayout` contínuos, `BattleLog` até 7 traps/níveis 1..5) |
| GAP-017 | S8/CI | `RaidClient` tem botões `<44px` (`34px`/`36px`) e troca silhuetas ao compactar unidades; `HordeKit`/`DropIn` afundam e excedem 8 partes; `check.sh` exclui client/controllers do `luau-lsp` | médio — falha toque mobile, distorce replay visual e deixa glue client/server sem análise estática no CI | no QA visual mobile da S8 e endurecimento do `check.sh` (**runbook: [`plano-playtest-v1.md`](plano-playtest-v1.md#3-fatia-s82--visual-3d-raycast-tap-to-build-áudio-replay--mobile-gap-017)** + [`RFC-001`](rfcs-p2-e-fechamento-gaps.md#2-rfc-001--integridade-s61s7--polimento-s8ci-pré-tráfego-p1-gap-014--gap-017)) | fechado em 13/11/2026 · Playtest V1 (`HordeKit` RootPart `<=8`p, `TrapKit` Y/chevrons, `ArenaVisual` 25 tiles raycast, `RaidClient` 44px + index by `id`, `BuildGridBoot`, `check.sh` `luau-lsp --platform=roblox` 0 erros + `visual-contract` 12/12) |
| GAP-018 | P2+ / V1.5 | Desbloqueio do Co-op Síncrono em tempo real (`lockstep` 20 Hz + `commands[]` no `BattleLog v2` + anti-leaver 90s) e Campanha Solo/Duo *Crônicas do Bastião* (5 Atos, 25 estágios, 3★, mutadores e 5 Bosses multi-lane no `Core`) sem runtime implementado | alto — sem `commands[]`, `TeleportService:ReserveServer` e máquina de estados de Boss no `Core`, co-op e campanha ficam só no papel | após autorização P2+ e `Core v4/v5` (**spec: [`RFC-007`](rfcs-p2-e-fechamento-gaps.md#8-rfc-007--co-op-síncrono-lockstep-campanha-soloduo--bosses-gap-018)** + [`campanha-bosses-e-coop-sincrono.md`](campanha-bosses-e-coop-sincrono.md)) | aberto |
| GAP-019 | S8.2 / P2+ | Falta OST adaptativa (`BGM_Bus` com 4 stems verticais + 5 temas horizontais), pool 3D de 36 cues SFX em `-14 LUFS`, máquina de animação 60 Hz (`Motor6D`/Spring) e Física Real Híbrida (`CollisionGroups` isolados, `BallSocketConstraint` ragdoll, fratura de portão em 12 blocos e governor mobile Low/Mid/High) | alto — sem áudio adaptativo e impacto físico visível, retenção D1 e viralidade de clipes 8s caem abaixo do benchmark | camada client (`BGM_Bus` + animações + ragdoll/fratura isolados) na S8.2/Playtest V1; camada F1 (`uImpulseX` no `Core`) na P2+ (**spec: [`RFC-008`](rfcs-p2-e-fechamento-gaps.md#9-rfc-008--soundscapeost-adaptativa-animações-60-hz--física-real-híbrida-gap-019)** + [`audio-musica-e-soundscape.md`](audio-musica-e-soundscape.md) + [`animacoes-fisica-real-e-vfx.md`](animacoes-fisica-real-e-vfx.md)) | aberto (camada client/SFX entregue em 13/11/2026: `I18n` 62 chaves PT/EN/ES, `AudioKit` + 35 SFX Cloud `Approved`, `Vfx` combos elementais + F2 ragdoll/fratura `CanQuery=false`, `HordeKit`/`TrapKit` 60Hz; resta F1 `uImpulseX` e 4 stems BGM para P2+) |
| GAP-020 | P2+ / Global | Faltam sistemas comerciais de jogo completo no runtime: FTUE 30 min (`ftueStep 0..6`), Relatório Pós-Partida + DPS Meter + Diagnóstico de Derrota, Contratos Diários/Semanais, Passe Cosmético, 12 `BadgeService`, Blueprint codes `MRL-XXXX`, Ordens/Leaderboards, `ProfileSettings` (acessibilidade/daltonismo/Gamepad), `ProcessReceipt` idempotente, `PolicyService` e Admin/Drain | alto — impede lançamento global multiplataforma e monetização segura sem violar políticas da Roblox | antes da abertura pública comercial P2+ (**spec: [`RFC-009`](rfcs-p2-e-fechamento-gaps.md#10-rfc-009--sistemas-comerciais-de-jogo-completo-processreceipt--policyservice-gap-020)** + [`sistemas-jogo-completo.md`](sistemas-jogo-completo.md)) | aberto |

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

**Próximo:** S7 **fechada** em 10/11/2026 (serviço/contrato 34/34). A expansão de classe/taxonomia
v2 continua bloqueada por GAP-004/008; GAP-011 fechou no `BattleLog`; GAP-012 abriu no sink Null.

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

## S6.1 — fechada: fantasma real + replay 3D + GAP-011 (10/11/2026)

Sem mudança de versão (`schema 2`, `content 2`, `sim 3`, hash `2489780106`). O `BattleLog` agora
persiste `contentVersion` e `isReplayable` recusa conteúdo futuro; `sim/raid-contract.luau` prova
hash de replay, 1 chave por `battle_id`, `wall` no log, `MuralhaPhantom_v1` e recompensa
idempotente. GAP-011 **fechado**; QA visual do replay 3D/fantasma fechado em
[`teste-s6-studio.md`](teste-s6-studio.md) §7. Próxima: S7.

## S7 — fechada: telemetria (10/11/2026)

Sem mudança de versão (`schema 2`, `content 2`, `sim 3`, hash `2489780106`). O
`AnalyticsService` monta o envelope v1, valida 100% dos eventos, faz lote (30 s/100), rate limit de
cliente (10/min), idempotência por `event_id` e entrega ao sink `Null`; `AnalyticsBoot` liga o
serviço a `Players`/perfil e `first_win_seconds` mede `first_win.ts − session_start.ts`. O contrato
`sim/analytics-contract.luau` está em **34/34** e prova que evento nenhum altera o `BattleResult`.
GAP-012 **fechado** em 10/11/2026 com `AnalyticsDataStoreSink` (`MuralhaAnalytics_v1`): produção
grava lotes em DataStore, Studio usa Memory e `AnalyticsSink=Null` continua disponível para QA. A
taxa de 70% agora tem série persistida para o teste de 3 semanas. QA em
[`teste-s7-studio.md`](teste-s7-studio.md).

## S8 — apresentação visual (10/11/2026)

Fatia de apresentação do P1 (não é P2): `VisualTheme`, diorama 5×5, 5 armadilhas 3D, 3 silhuetas de
horda, UI de cartões, VFX/SFX e replay no mesmo kit. O servidor continua autoritativo; nada muda em
schema/content/sim/taxonomia. Contrato visual **8/8**; QA em
[`teste-s8-studio.md`](teste-s8-studio.md). Sem gap novo; áudio usa sons embutidos como placeholder
(troca por SFX originais é polimento opcional).

## Pesquisa regional — GAP-013 (12/11/2026)

A pergunta “ticket médio fora do Brasil” não tinha resposta no projeto; o benchmark de monetização
era **global por jogo**. A pesquisa [`pesquisa-monetizacao-regional.md`](pesquisa-monetizacao-regional.md)
fechou o que dá para saber com fonte oficial:

- receita 2025: EUA+Canadá **61%**, Europa **19%**, APAC **11%**, ROW **9%** — Brasil dentro do ROW,
  sem abertura; nenhum país além dos EUA passa de 10%;
- ABPDAU Q3 FY26: EUA+Canadá **US$ 38,52**, Europa **US$ 11,20**, APAC **US$ 5,37**, ROW
  **US$ 5,07** — bookings por DAU, **não ARPPU**;
- ARPPU por país e ticket por compra (AOV) continuam **não medidos**; o ARPPU global por jogo da
  GameAnalytics (p50 US$ 0,70; p90 US$ 2,33; p95 US$ 4,80) não substitui o recorte regional;
- o próprio Creator Analytics permite medir ARPPU/conversão por país e exportar sales data; a
  telemetria atual só tem `locale`, não país.

**GAP-013 aberto:** fechar antes de P2/loja/precificação internacional. P2 continua bloqueada.

## Revisão de Literatura, Catálogo, Sistemas e Auditoria Arquitetural (13/11/2026)

Durante a pausa da P1 (sem alterar código, schema, catálogo ou motor), foram produzidos cinco documentos mestres e uma auditoria técnica completa (`AUD-01..AUD-12`):

- [`literatura-e-universo.md`](literatura-e-universo.md) — bíblia de universo (*Arquiteto-Mor da Ordem do Âmbar* vs *Fendas Mercenárias*), justificativa diegética zero-avatar, 5 comandantes, micro-literatura e quick-chat.
- [`catalogo-itens-e-cosmeticos.md`](catalogo-itens-e-cosmeticos.md) — catálogo P1 + backlog horizontal P2/P3 (7 armadilhas/estruturas, 4 unidades da horda, plantas, cosméticos e passe regionalizado).
- [`skills-tiers-e-modos.md`](skills-tiers-e-modos.md) — sinergias espaciais puras, *Gambits* programáveis, traits horizontais, calibração do Dia 1, 7 ligas, tiers Nv1–Nv5 e matriz de 7 modos.
- [`direcao-visual-e-silhuetas.md`](direcao-visual-e-silhuetas.md) — hierarquia 3 camadas, matriz ortogonal L1–L5 × Tier Cosmético, 4 estados de destruição da muralha, UX mobile e pipeline Blender→Studio.
- [`arquitetura-e-fluxos.md`](arquitetura-e-fluxos.md) — diagramas de topologia, 5 fluxos end-to-end, arquitetura P2 para 25k DAU e matriz `AUD-01..AUD-12` (origina `GAP-014..017`).

## Pacote de Especificação Zero-Brechas & RFCs (13/11/2026)

Todos os gaps abertos possuem especificação pronta para execução imediata na respectiva janela (sem alterar código durante a pausa da P1):

- [`plano-playtest-v1.md`](plano-playtest-v1.md) — runbook passo a passo para entregar o **Playtest Bonito, Profundo e Jogável** (Fatia S8.1: `GAP-014` + progressão L1–L5 + pool de fantasmas/bots; Fatia S8.2: `GAP-017` + Y-offset 3D + raycast tap-to-build + áudio offline/OST/física local; Fatia S8.3 opcional sob `SIM_VERSION = 4`: sinergias espaciais).
- [`rfcs-p2-e-fechamento-gaps.md`](rfcs-p2-e-fechamento-gaps.md) — compêndio completo de RFCs (`RFC-001` a `RFC-009`) cobrindo `GAP-004..GAP-020`.

## Desbloqueio Co-op Síncrono & Física Real + Integração dos 3 Pilares e Jogo Completo (13/11/2026)

Por decisão explícita do diretor (`AGENTS.md`: *Decisão humana > código + teste > documento*), foram **desbloqueados** o **Co-op Síncrono em Tempo Real** e a **Física Real Híbrida** (`.context/REJEITADOS.md` reaberto sob critérios objetivos), mantendo intacto o núcleo P1 (`S1–S8`) até a medição do teste de 3 semanas:

- [`audio-musica-e-soundscape.md`](audio-musica-e-soundscape.md) — Pilar 1: barramentos `SoundService`/`MuralhaMaster`, música adaptativa vertical (4 stems) e horizontal (5 Atos), 36 cues SFX 3D + física, stingers de 8s e pipeline `-14 LUFS`.
- [`campanha-bosses-e-coop-sincrono.md`](campanha-bosses-e-coop-sincrono.md) — Pilar 2 + Co-op Síncrono: Campanha *Crônicas do Bastião* (5 Atos × 5 estágios, Solo/Duo Assíncrono/Duo Síncrono), escalonamento inteiro, selos 3★, 8 mutadores, 5 Bosses multi-lane no `Core` e Co-op Síncrono *lockstep* `20 Hz` com anti-leaver 90s e replay 8s preservado.
- [`animacoes-fisica-real-e-vfx.md`](animacoes-fisica-real-e-vfx.md) — Pilar 3: Física Real Híbrida (`Core` impulsos inteiros + `CollisionGroups` isolados com `BallSocketConstraint` ragdoll e fratura do portão em 12 blocos sob governor Low/Mid/High), máquinas de animação 60 Hz e catálogo completo de VFX.
- [`sistemas-jogo-completo.md`](sistemas-jogo-completo.md) — Fechamento comercial completo: FTUE 30 min (`ftueStep 0..6`), Pós-Partida/DPS Meter, Contratos/Passe/12 Badges, Ordens/Blueprints `MRL-XXXX`, Configurações/Daltonismo/Gamepad/i18n e Loja `ProcessReceipt` + `PolicyService` + Admin/Drain.
