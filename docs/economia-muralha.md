# Economia da muralha — S3/S3.4 (10/11/2026)

> Primeira calibragem da P1. Os números são ponto de partida; mudança de custo/desbloqueio exige
> atualizar este documento **e** o contrato (`sim/walls-contract.luau`). Processo completo de
> expansão: [`pipeline-expansao.md`](pipeline-expansao.md). Fonte executável:
> [`../src/shared/data/TrapCatalog.luau`](../src/shared/data/TrapCatalog.luau) (dados) e
> [`../src/server/walls/WallService.luau`](../src/server/walls/WallService.luau) (regras).

---

## 1. Catálogo

O catálogo espelha os **5 tipos que o motor v3 simula** (`Core.TRAP` / `Core.TRAP_NAMES`).
`oil` foi renomeada para `tar` na S3.4 (alias de migração) e `catapult` entrou como 5º tipo.

| Trap | Custo | Upgrade base | Desbloqueio |
|---|---:|---:|---|
| `archer` | 40 | 30 | liga 1 (0 pontos) |
| `tar` | 60 | 45 | liga 2 (100 pontos) |
| `frost` | 90 | 65 | liga 3 (200 pontos) |
| `cannon` | 140 | 100 | liga 4 (300 pontos) |
| `catapult` | 180 | 130 | liga 5 (400 pontos) |

- **Fonte única:** `src/shared/data/TrapCatalog.luau` (`TRAPS`, `TRAP_IDS`, `TRAP_ALIASES`,
  `MAX_LEVEL`, `POINTS_PER_LEAGUE`, `GOLD_SOURCES`, `GOLD_SINKS`, `CONTENT_VERSION`). O
  `WallService` recebe o catálogo por injeção; não há cópia de custos no serviço.
- **Liga:** `TrapCatalog.leagueOf(points) = 1 + floor(points / 100)`.
- **Upgrade:** do nível `n` para `n+1` custa `upgrade * n` (nível atual). Ex.: archer 1→2 = 30;
  2→3 = 60. No modo UPGRADE a UI mostra a faixa `upgrade/2*upgrade` (30/60); ao tocar na célula o
  status mostra o custo exato pelo nível atual e, após a ação, o valor realmente debitado.
- **Nível máximo:** **3** (`TrapCatalog.MAX_LEVEL`, GDD §5). O schema aceita até 5 para expansão
  futura, mas a economia da P1 trava em 3.
- **N=5 ativas**, célula `rXcY` (linha = lane, coluna = profundidade), colocação livre nas 25.
- O limite efetivo é `min(profile.wall.activeTrapLimit, schema.ACTIVE_TRAP_LIMIT)`: o perfil manda,
  mas a S3 nunca passa de 5.

## 2. Ouro

- `WallService.creditGold(amount, source, battleId?)` credita ouro ganho em raid/defesa/diário.
- `source` aceita **`raid`**, **`defense`** e **`daily`** (`TrapCatalog.GOLD_SOURCES`, enums da
  taxonomia v1); `battle_id` é opcional.
- Teto: `ProfileSchema.MAX_GOLD` (1.000.000.000). O serviço recusa (`gold_cap`) em vez de truncar.
- **Remover não devolve ouro.** A taxonomia v1 não tem `source` de refund e `gold_earned` só aceita
  os três enums acima; reembolso exigiria taxonomia v2. Remover é mudança de layout, não fonte de
  renda.

## 3. Persistência

`WallService` muta o `Profile.Data` vivo:

- `profile.wall.cells[cell] = { trap = trapId, level = 1 }`;
- `profile.gold -= custo` (place/upgrade) ou `+= amount` (creditGold).

Depois de cada operação o serviço roda `ProfileSchema.validate(profile)` e falha alto se o estado
não for válido. O `ProfileStore` autosalva o `Profile.Data`; o serviço não chama `Save` (a S4/S6
decidem o momento de persistência explícita).

Na criação, `WallService.new` roda `WallService.validateWall` e **falha fechado** se o perfil
carregar trap desconhecida, célula fora da grade/alias, mais ativos que o limite, nível acima do
cap econômico ou `contentVersion` diferente do catálogo. Esses dados nunca chegam ao motor
(`Battle.new`). O boot (`ProfileBoot`) roda `TrapCatalog.ensureProfileContent` antes de expor
`Data`: perfil v1 é reparado (`oil → tar`) e perfil futuro é recusado (`content_future`).

A ponte perfil → motor é `WallService.toBattleWall(profile, schema, catalog, hp)`: ele roda
`validateWall`, converte `wall.cells` em `wall.traps` e ordena por célula (linha, coluna). A S4/S6
não monta `wall.traps` à mão; perfil inválido devolve `nil + erro` e não chega ao `Battle.new`.

## 4. Eventos (taxonomia v1)

| Ação | Eventos |
|---|---|
| colocar | `trap_placed` (`trap_id`, `cell`, `cost`) + `gold_spent` (`amount`, `sink="trap"`) |
| evoluir | `upgrade_bought` (`target=cell`, `level`, `cost`) + `gold_spent` (`amount`, `sink="upgrade"`) |
| creditar ouro | `gold_earned` (`amount`, `source`, `battle_id?`) |
| remover | nenhum (a taxonomia não tem `trap_removed`) |

O serviço devolve `events = { { name, props } }` e, se receber `emit`, publica `emit(name, props)`.
O envelope/`event_id`/sink é responsabilidade do `AnalyticsService` (S7, implementado em
10/11/2026); o contrato monta o envelope e valida cada evento com `AnalyticsTypes.validate`.

## 5. Erros estáveis

`invalid_cell`, `cell_occupied`, `empty_cell`, `trap_limit`, `unknown_trap`, `trap_locked`,
`insufficient_gold`, `max_level`, `gold_cap`, `invalid_amount`, `invalid_source`,
`content_version`, `content_future`.

## 6. API e teste

Controlador no estilo do `ProfileService` (chamada com ponto):

```lua
local service = WallService.new({
    profile = profile.Data,
    schema = ProfileSchema,
    catalog = TrapCatalog,
})
local result, err = service.place("archer", "r1c3")
local result, err = service.upgrade("r1c3")
local result, err = service.remove("r1c3")
local result, err = service.creditGold(120, "raid", battleId)

local wall, wallErr = WallService.toBattleWall(profile.Data, ProfileSchema, TrapCatalog, 500)
```

Contrato headless: `luau sim/walls-contract.luau` — **13 checagens** (catálogo x motor, fontes/sinks,
perfil carregado, `toBattleWall`, célula, N=5, ouro, desbloqueio, upgrade, remove, creditGold,
snapshot e eventos). Conteúdo/versões: `luau sim/content-contract.luau` — **7 checagens** (5 tipos,
alias, `contentVersion`, gate e hash antigo x migrado).

## 7. Como expandir sem quebrar

**Novo custo/desbloqueio de um tipo existente:** editar `TrapCatalog`, este documento e o contrato
na mesma mudança. O teste ancora custos, desbloqueios, `TRAP_IDS`, `GOLD_SOURCES` e `GOLD_SINKS`;
CI falha se divergir.

**Novo tipo de armadilha:**

1. adicionar stats em `Core.TRAP` **e** o nome em `Core.TRAP_NAMES`;
2. adicionar a entrada em `TrapCatalog.TRAPS` e `TrapCatalog.TRAP_IDS`;
3. rodar `sim/invariants.luau`, `sim/acceptance.luau` e `sim/walls-contract.luau`; a paridade
   `TRAPS == Core.TRAP` e o teste "cada tipo roda no motor" falham se faltar um dos lados;
4. decidir `simVersion`: se a matemática/estatística do motor mudou, subir a versão e re-ancorar
   hash/acceptance/spec; replay antigo não pode pagar recompensa;
5. **nunca renomear/remover um `trap_id` sem migração de perfil** — o schema guarda string e o
   `WallService` falha fechado; perfis antigos com o ID removido precisam de migração/limpeza
   explícita antes do deploy. Registre a mudança e suba `TrapCatalog.CONTENT_VERSION`;
6. atualizar `docs/economia-muralha.md`, `docs/spec-motor-deterministico.md`, `docs/versoes.md`
   e o runbook de deploy. Tipo novo/renomeado exige `CONTENT_VERSION++`; se aparece em batalha,
   `SIM_VERSION++` + re-ancoragem de hash/acceptance (política do GAP-003).

**Novo nível de upgrade:** atualizar `TrapCatalog.MAX_LEVEL`, este documento e o contrato. O
`schema.MAX_TRAP_LEVEL` (5) e `Core` já suportam até 5; a taxonomia também valida `level` 1..5.
Acima de 5 exige mudança na taxonomia/schema, não só no catálogo.

**Novo item cosmético:** o schema já aceita `profile.cosmetics[id] = true`; adicione o ID ao
catálogo de loja/inventário e teste o limite `MAX_COSMETICS`. Cosmético não entra no motor nem no
replay; não precisa de `simVersion`.

**Nova classe/trait de armadilha:** hoje `Cell = { trap, level }`; não existe campo de classe,
raridade ou trait. Criar isso é **schema v2 + migração + extensão do motor/motor de batalha**, não
uma entrada no `TrapCatalog`. Não simule classe só no serviço: o replay precisa do mesmo contrato.

**Nova fonte/sink de ouro:** primeiro estender os enums da taxonomia (v2) e o contrato; só depois
adicionar em `TrapCatalog.GOLD_SOURCES`/`GOLD_SINKS`. O teste de contrato valida cada chave contra
`AnalyticsTypes` e falha se o enum não existir.

**Pendência para conteúdo em produção:** GAP-004/005/008/009 em [`gaps.md`](gaps.md).
`CONTENT_VERSION` já é persistido no perfil (`contentVersion`) com reparo/recusa no boot; o
`BattleLog` da S6 deve carregar a mesma versão antes de conteúdo em massa. O GAP-009 (ProfileStore
real com schema v2) foi fechado no Modo B em 10/11/2026; o GAP-011 fechou no `BattleLog` da S6.
