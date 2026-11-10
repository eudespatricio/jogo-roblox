# Economia da muralha — S3 (09/11/2026)

> Primeira calibragem da P1. Os números são ponto de partida; mudança de custo/desbloqueio exige
> atualizar este documento **e** o contrato (`sim/walls-contract.luau`). Fonte executável:
> [`../src/server/walls/WallService.luau`](../src/server/walls/WallService.luau).

---

## 1. Catálogo

O catálogo espelha os **4 tipos que o motor v2 simula** (`Core.TRAP_NAMES`). O 5º tipo do GDD
(§5) só entra quando o motor souber simulá-lo; não inventar tipo no serviço.

| Trap | Custo | Upgrade base | Desbloqueio |
|---|---:|---:|---|
| `archer` | 40 | 30 | liga 1 (0 pontos) |
| `oil` | 60 | 45 | liga 2 (100 pontos) |
| `frost` | 90 | 65 | liga 3 (200 pontos) |
| `cannon` | 140 | 100 | liga 4 (300 pontos) |

- **Liga:** `1 + floor(league.points / 100)`; 100 pontos por liga (`WallService.POINTS_PER_LEAGUE`).
- **Upgrade:** do nível `n` para `n+1` custa `upgrade * n` (nível atual). Ex.: archer 1→2 = 30;
  2→3 = 60.
- **Nível máximo:** **3** (GDD §5). O schema aceita até 5 para expansão futura, mas a economia da
  P1 trava em 3.
- **N=5 ativas**, célula `rXcY` (linha = lane, coluna = profundidade), colocação livre nas 25.
- O limite efetivo é `min(profile.wall.activeTrapLimit, schema.ACTIVE_TRAP_LIMIT)`: o perfil manda,
  mas a S3 nunca passa de 5.

## 2. Ouro

- `WallService.creditGold(amount, source, battleId?)` credita ouro ganho em raid/defesa/diário.
- `source` aceita **`raid`**, **`defense`** e **`daily`** (enums da taxonomia v1); `battle_id` é
  opcional.
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

## 4. Eventos (taxonomia v1)

| Ação | Eventos |
|---|---|
| colocar | `trap_placed` (`trap_id`, `cell`, `cost`) + `gold_spent` (`amount`, `sink="trap"`) |
| evoluir | `upgrade_bought` (`target=cell`, `level`, `cost`) + `gold_spent` (`amount`, `sink="upgrade"`) |
| creditar ouro | `gold_earned` (`amount`, `source`, `battle_id?`) |
| remover | nenhum (a taxonomia não tem `trap_removed`) |

O serviço devolve `events = { { name, props } }` e, se receber `emit`, publica `emit(name, props)`.
O envelope/`event_id`/sink é responsabilidade do `AnalyticsService` (S7). O contrato monta o
envelope e valida cada evento com `AnalyticsTypes.validate`.

## 5. Erros estáveis

`invalid_cell`, `cell_occupied`, `empty_cell`, `trap_limit`, `unknown_trap`, `trap_locked`,
`insufficient_gold`, `max_level`, `gold_cap`, `invalid_amount`, `invalid_source`.

## 6. API e teste

Controlador no estilo do `ProfileService` (chamada com ponto):

```lua
local service = WallService.new({ profile = profile.Data, schema = ProfileSchema })
local result, err = service.place("archer", "r1c3")
local result, err = service.upgrade("r1c3")
local result, err = service.remove("r1c3")
local result, err = service.creditGold(120, "raid", battleId)
```

Contrato headless: `luau sim/walls-contract.luau` — 11 checagens (catálogo, célula, N=5, ouro,
desbloqueio, upgrade, remove, creditGold, snapshot e eventos válidos).
