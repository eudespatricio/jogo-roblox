# GAPS — lacunas conhecidas entre P's e S's

> **Convenção:** toda fase P ou fatia S fecha com **uma linha** `GAP:` no handoff
> (`CONTINUAR.md`). Gap aberto vira **uma linha** nesta tabela, com gatilho objetivo para fechar.
> Sem gatilho, a linha não entra. Ver `docs/pipeline-expansao.md` §7.

**Linha atual:**

```text
GAP: GAP-001..GAP-005, GAP-008..GAP-010 · conteúdo em produção ainda exige versão/migração; analytics sem variantes; ProfileStore real não testado; default neutro preparado no kit · risco alto para updates semanais · fechar antes da 1ª expansão de conteúdo/P2 (GAP-010 no 1º schema v2) · ver docs/gaps.md
```

| ID | Fase | Gap | Risco | Gatilho para fechar | Status |
|---|---|---|---|---|---|
| GAP-001 | S3.1 | `TrapCatalog.CONTENT_VERSION` não é persistido no perfil nem no `BattleLog`; não há gate de versão entre servidores antigo/novo | alto — perfil escrito com conteúdo novo pode travar em servidor antigo; replay não prova a versão do conteúdo | antes do primeiro tipo/classe novo em produção | aberto |
| GAP-002 | S3.1 | sem migração/repair para `trap_id` renomeado ou removido; `WallService.validateWall` falha fechado e pode trancar o jogador | alto — renomear/remover conteúdo vira lockout; a única saída hoje é migração manual | antes de qualquer rename/remove de trap | aberto |
| GAP-003 | S3.1 | stats do motor continuam hardcoded em `Core.TRAP`/`TRAP_NAMES`; tipo novo exige editar motor + decidir `simVersion`; 5º tipo do GDD não existe no motor | alto — cada expansão de conteúdo vira mudança de motor e re-ancoragem de hash | antes de escalar conteúdo além dos 4 tipos / antes do 5º tipo | aberto |
| GAP-004 | S3.1 | `Cell` só tem `trap` e `level`; classe, raridade e trait não existem no schema nem no motor | médio — a primeira feature de classe exige schema v2 + migração + replay | quando classe/trait entrar no roadmap | aberto |
| GAP-005 | P2 | sem sistema de eventos/feature flags/calendário; atualização semanal e evento sazonal dependem de deploy de código | alto — live ops sem cadência; risco de update quebrar servidor em produção | antes do primeiro evento semanal/sazonal | aberto |
| GAP-006 | S4 | a guarda de perfil só roda se o servidor usar `WallService`; não há helper `toBattleWall` que force a validação antes de `Battle.new` | médio — S4/S6 podem montar `wall.traps` direto e furar a guarda | revisão de código da S4 / antes de ligar UI de build | fechado em 10/11/2026 · `42187a5` · `toBattleWall` + 13/13 (`sim/walls-contract.luau`) |
| GAP-007 | S3.2 (trial) | docs podem ficar velhas sem o CI reclamar: o `check.sh` passou verde com labels “schema v1/motor v2” e spec antiga | alto — doc mais velho que código mente e contamina a próxima janela | antes de qualquer expansão real; revisar labels e criar check de versão nos docs | fechado em 10/11/2026 · `42187a5` · `scripts/check-versions.py` + `docs/versoes.md` |
| GAP-008 | S3.2 (trial) | `trap_placed`/`upgrade_bought` não carregam class/trait/rarity; a taxonomia v1 é congelada | médio — live ops e funil não conseguem segmentar variantes | quando variantes forem para produção (taxonomia v2) | aberto |
| GAP-009 | S3.2 (trial) | schema v2 não foi testado em ProfileStore/Studio real; `STORE_NAME` continua `MuralhaProfile_v1` com `schemaVersion=2` | alto — Reconcile/DataStore real pode se comportar diferente do store fake | antes do deploy de schema v2 | aberto |
| GAP-010 | S3.2 (trial) | default de migração neutro não é garantido por teste; um default com bônus mudaria o hash sem ninguém ver | alto — migração silenciosa buffa/nerfa muralhas antigas | em toda migração de conteúdo; teste de hash antigo x migrado | aberto — preparado em 10/11/2026 · `42187a5` · kit `neutral-migration.luau`; fecha no 1º schema v2 |

## Como fechar um gap

1. O gatilho da tabela é objetivo; se não chegou, o gap fica aberto (não vira tarefa solta).
2. Ao fechar, atualizar a linha para `fechado em <data> · <commit/PR>` e registrar o teste que prova.
3. Se o gap mudar de forma, criar novo ID e apontar o antigo como `substituído por GAP-xxx`.
4. O `CONTINUAR.md` da janela seguinte carrega a linha `GAP:` atualizada.

## Fechamento antes da S4 — S3.3 executada (10/11/2026)

**Resultado:** a janela **S3.3** fechou GAP-006 e GAP-007 e preparou GAP-010. Os demais gaps são de
conteúdo/feature/P2 e não bloqueiam a cena/build.

| GAP | Status | Trabalho | Prova |
|---|---|---|---|
| GAP-006 | **fechado** | `WallService.toBattleWall(profile, schema, catalog, hp)` valida, ordena e converte `cells` em `wall.traps`; S4 usa só esse helper | perfil válido/inválido, ordem determinística e hash igual em `sim/walls-contract.luau` (13/13) |
| GAP-007 | **fechado** | `scripts/check-versions.py` no `check.sh` compara `SCHEMA_VERSION`, `CONTENT_VERSION`, `SIM_VERSION` e hash com `docs/versoes.md`; labels saem da fonte | divergência simulada falha; versão atual passa |
| GAP-010 | **preparado** | `tools/expansion-test/neutral-migration.luau` compara hash da parede antiga x migrada; roda no `check.sh` para 0→1 | fecha de fato no primeiro schema v2 |
| GAP-009 | não | exige schema v2 + ProfileStore/Studio real | depois do primeiro schema v2 |
| GAP-001 | não | `contentVersion` no perfil + `BattleLog` | fatia de conteúdo; parte final depende da S6 |
| GAP-002 | não | migração/repair de `trap_id` renomeado/removido | fatia de conteúdo |
| GAP-003 | não | stats do motor fora do código ou política explícita de `simVersion` por tipo | fatia de conteúdo/engine |
| GAP-004 | não | classe/trait/raridade no schema real (o trial provou o mecanismo) | feature de classe |
| GAP-008 | não | campos de variante na taxonomia v2 | feature de classe/variantes |
| GAP-005 | não | eventos/flags/calendário | P2/live ops |

**Próximo:** S4 (cena 5×5 + build). A expansão de conteúdo continua bloqueada pelos gaps de
versão/migração/engine; GAP-010 fecha junto com o primeiro schema v2.
