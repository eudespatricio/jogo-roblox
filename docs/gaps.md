# GAPS — lacunas conhecidas entre P's e S's

> **Convenção:** toda fase P ou fatia S fecha com **uma linha** `GAP:` no handoff
> (`CONTINUAR.md`). Gap aberto vira **uma linha** nesta tabela, com gatilho objetivo para fechar.
> Sem gatilho, a linha não entra. Ver `docs/pipeline-expansao.md` §7.

**Linha atual:**

```text
GAP: GAP-001..GAP-010 · conteúdo em produção ainda exige versão/migração; docs e analytics não acompanham variantes; ProfileStore real não testado · risco alto para updates semanais · fechar antes da 1ª expansão de conteúdo/P2 · ver docs/gaps.md
```

| ID | Fase | Gap | Risco | Gatilho para fechar | Status |
|---|---|---|---|---|---|
| GAP-001 | S3.1 | `TrapCatalog.CONTENT_VERSION` não é persistido no perfil nem no `BattleLog`; não há gate de versão entre servidores antigo/novo | alto — perfil escrito com conteúdo novo pode travar em servidor antigo; replay não prova a versão do conteúdo | antes do primeiro tipo/classe novo em produção | aberto |
| GAP-002 | S3.1 | sem migração/repair para `trap_id` renomeado ou removido; `WallService.validateWall` falha fechado e pode trancar o jogador | alto — renomear/remover conteúdo vira lockout; a única saída hoje é migração manual | antes de qualquer rename/remove de trap | aberto |
| GAP-003 | S3.1 | stats do motor continuam hardcoded em `Core.TRAP`/`TRAP_NAMES`; tipo novo exige editar motor + decidir `simVersion`; 5º tipo do GDD não existe no motor | alto — cada expansão de conteúdo vira mudança de motor e re-ancoragem de hash | antes de escalar conteúdo além dos 4 tipos / antes do 5º tipo | aberto |
| GAP-004 | S3.1 | `Cell` só tem `trap` e `level`; classe, raridade e trait não existem no schema nem no motor | médio — a primeira feature de classe exige schema v2 + migração + replay | quando classe/trait entrar no roadmap | aberto |
| GAP-005 | P2 | sem sistema de eventos/feature flags/calendário; atualização semanal e evento sazonal dependem de deploy de código | alto — live ops sem cadência; risco de update quebrar servidor em produção | antes do primeiro evento semanal/sazonal | aberto |
| GAP-006 | S4 | a guarda de perfil só roda se o servidor usar `WallService`; não há helper `toBattleWall` que force a validação antes de `Battle.new` | médio — S4/S6 podem montar `wall.traps` direto e furar a guarda | revisão de código da S4 / antes de ligar UI de build | aberto |
| GAP-007 | S3.2 (trial) | docs podem ficar velhas sem o CI reclamar: o `check.sh` passou verde com labels “schema v1/motor v2” e spec antiga | alto — doc mais velho que código mente e contamina a próxima janela | antes de qualquer expansão real; revisar labels e criar check de versão nos docs | aberto |
| GAP-008 | S3.2 (trial) | `trap_placed`/`upgrade_bought` não carregam class/trait/rarity; a taxonomia v1 é congelada | médio — live ops e funil não conseguem segmentar variantes | quando variantes forem para produção (taxonomia v2) | aberto |
| GAP-009 | S3.2 (trial) | schema v2 não foi testado em ProfileStore/Studio real; `STORE_NAME` continua `MuralhaProfile_v1` com `schemaVersion=2` | alto — Reconcile/DataStore real pode se comportar diferente do store fake | antes do deploy de schema v2 | aberto |
| GAP-010 | S3.2 (trial) | default de migração neutro não é garantido por teste; um default com bônus mudaria o hash sem ninguém ver | alto — migração silenciosa buffa/nerfa muralhas antigas | em toda migração de conteúdo; teste de hash antigo x migrado | aberto |

## Como fechar um gap

1. O gatilho da tabela é objetivo; se não chegou, o gap fica aberto (não vira tarefa solta).
2. Ao fechar, atualizar a linha para `fechado em <data> · <commit/PR>` e registrar o teste que prova.
3. Se o gap mudar de forma, criar novo ID e apontar o antigo como `substituído por GAP-xxx`.
4. O `CONTINUAR.md` da janela seguinte carrega a linha `GAP:` atualizada.

## Fechamento antes da S4 (09/11/2026)

**Recomendação:** uma janela curta **S3.3** fecha GAP-006 + GAP-007 e prepara GAP-010; depois S4.
Os demais gaps são de conteúdo/feature/P2 e não devem bloquear a cena/build.

| GAP | Fechável antes da S4? | Trabalho | Critério de pronto |
|---|---|---|---|
| GAP-006 | **sim** | `WallService.toBattleWall(profile, schema, catalog, hp)` que valida e converte `cells` em `wall.traps` ordenado por célula; S4 usa só esse helper | helper testado com perfil válido/inválido; ordem determinística; mesma parede = mesmo hash |
| GAP-007 | **sim** | `scripts/check-versions.py` (ou equivalente) no `check.sh`: compara `SCHEMA_VERSION`, `CONTENT_VERSION`, `SIM_VERSION` e hash com um bloco de versões nos docs; corrigir labels “schema v1/motor v2” | CI falha se fonte e docs divergirem; labels atuais passam |
| GAP-010 | **preparar** | template/teste de migração neutra no kit; hash de parede antiga x migrada | fecha de fato no primeiro schema v2 (depende de feature) |
| GAP-009 | não | exige schema v2 + ProfileStore/Studio real | depois do primeiro schema v2 |
| GAP-001 | não | `contentVersion` no perfil + `BattleLog` | fatia de conteúdo; parte final depende da S6 |
| GAP-002 | não | migração/repair de `trap_id` renomeado/removido | fatia de conteúdo |
| GAP-003 | não | stats do motor fora do código ou política explícita de `simVersion` por tipo | fatia de conteúdo/engine |
| GAP-004 | não | classe/trait/raridade no schema real (o trial provou o mecanismo) | feature de classe |
| GAP-008 | não | campos de variante na taxonomia v2 | feature de classe/variantes |
| GAP-005 | não | eventos/flags/calendário | P2/live ops |

**S3.3 — escopo sugerido:** GAP-006 e GAP-007. **Não** iniciar S4 antes do helper de parede e do
gate de versões; **não** tentar fechar GAP-001/002/003/009 nesta janela sem uma feature de conteúdo.
