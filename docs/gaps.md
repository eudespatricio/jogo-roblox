# GAPS — lacunas conhecidas entre P's e S's

> **Convenção:** toda fase P ou fatia S fecha com **uma linha** `GAP:` no handoff
> (`CONTINUAR.md`). Gap aberto vira **uma linha** nesta tabela, com gatilho objetivo para fechar.
> Sem gatilho, a linha não entra. Ver `docs/pipeline-expansao.md` §7.

**Linha atual:**

```text
GAP: GAP-001..GAP-006 · conteúdo em produção ainda exige versão/migração; stats do motor são código; classes e eventos não modelados · risco alto para updates semanais · fechar antes da 1ª expansão de conteúdo/P2 · ver docs/gaps.md
```

| ID | Fase | Gap | Risco | Gatilho para fechar | Status |
|---|---|---|---|---|---|
| GAP-001 | S3.1 | `TrapCatalog.CONTENT_VERSION` não é persistido no perfil nem no `BattleLog`; não há gate de versão entre servidores antigo/novo | alto — perfil escrito com conteúdo novo pode travar em servidor antigo; replay não prova a versão do conteúdo | antes do primeiro tipo/classe novo em produção | aberto |
| GAP-002 | S3.1 | sem migração/repair para `trap_id` renomeado ou removido; `WallService.validateWall` falha fechado e pode trancar o jogador | alto — renomear/remover conteúdo vira lockout; a única saída hoje é migração manual | antes de qualquer rename/remove de trap | aberto |
| GAP-003 | S3.1 | stats do motor continuam hardcoded em `Core.TRAP`/`TRAP_NAMES`; tipo novo exige editar motor + decidir `simVersion`; 5º tipo do GDD não existe no motor | alto — cada expansão de conteúdo vira mudança de motor e re-ancoragem de hash | antes de escalar conteúdo além dos 4 tipos / antes do 5º tipo | aberto |
| GAP-004 | S3.1 | `Cell` só tem `trap` e `level`; classe, raridade e trait não existem no schema nem no motor | médio — a primeira feature de classe exige schema v2 + migração + replay | quando classe/trait entrar no roadmap | aberto |
| GAP-005 | P2 | sem sistema de eventos/feature flags/calendário; atualização semanal e evento sazonal dependem de deploy de código | alto — live ops sem cadência; risco de update quebrar servidor em produção | antes do primeiro evento semanal/sazonal | aberto |
| GAP-006 | S4 | a guarda de perfil só roda se o servidor usar `WallService`; não há helper `toBattleWall` que force a validação antes de `Battle.new` | médio — S4/S6 podem montar `wall.traps` direto e furar a guarda | revisão de código da S4 / antes de ligar UI de build | aberto |

## Como fechar um gap

1. O gatilho da tabela é objetivo; se não chegou, o gap fica aberto (não vira tarefa solta).
2. Ao fechar, atualizar a linha para `fechado em <data> · <commit/PR>` e registrar o teste que prova.
3. Se o gap mudar de forma, criar novo ID e apontar o antigo como `substituído por GAP-xxx`.
4. O `CONTINUAR.md` da janela seguinte carrega a linha `GAP:` atualizada.
