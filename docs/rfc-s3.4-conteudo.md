# RFC — S3.4 conteúdo e versões (GAP-001/002/003/009/010)

- **Data / responsável:** 10/11/2026 · agentes (motor/CI + sistemas/economia)
- **Tipo:** conteúdo + schema + motor
- **Versões:** schema **1 → 2** · content **1 → 2** · sim **2 → 3**
- **Jogador:** 5º tipo de armadilha (`catapult`, dano em área na lane) e `oil` renomeada para `tar`
  (piche; mesmas estatísticas). O jogador antigo mantém a muralha: `oil` vira `tar` na migração.
- **Economia:** `catapult` custa 180, upgrade 130, desbloqueia na liga 5 (400 pontos); `tar`
  mantém 60/45/liga 2. Sem nova fonte/sink de ouro; remover continua sem refund.
- **Replay:** `contentVersion` passa a ser persistido no perfil; o `BattleLog` da S6 deve carregar a
  mesma versão. Servidor com catálogo antigo recusa `contentVersion` futura (`content_future`);
  servidor novo migra perfil antigo antes de expor `Data`.
- **Migração:** schema 1→2 adiciona `contentVersion = 1` (conteúdo legado); a migração de conteúdo
  1→2 resolve `oil → tar` por alias e sobe `contentVersion` para 2. `trap_id` desconhecido continua
  falhando fechado; rename/remove deve entrar em `TrapCatalog.TRAP_ALIASES`/`TRAP_REMOVALS`.
- **Motor:** `simVersion 3` porque o motor ganhou `splash` (catapult atinge todas as unidades na
  lane dentro do alcance) e o catálogo renomeou um tipo. A parede padrão (`Core.defaultWall`) usa
  `tar` no lugar de `oil`; o hash de referência deve continuar `2489780106` (estatísticas iguais).
- **Testes:** contracts de perfil/conteúdo/muralha, invariantes, acceptance, analytics, migração
  neutra (hash antigo x migrado) e `doctor`/`check`/CI.
- **Rollout / rollback:** publicar com API Services ligado; perfis v2 são recusados por servidor
  antigo (`schema_future`/`content_future`), sem sobrescrever. Rollback = reverter o commit; o
  perfil v2 permanece no store e o servidor antigo recusa até o rollback completo.
- **GAP:** GAP-001/002/003/009/010 fechados com a fatia; o Modo B schema v2 foi executado em
  10/11/2026 (`schema=v2 content=v2`, 8/8). GAP-011 (`contentVersion` no `BattleLog`) fechou na S6.
