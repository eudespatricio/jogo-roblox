# Versões — fonte executável x documentação

> **Gate:** `python3 scripts/check-versions.py` roda no `scripts/check.sh` e falha se o bloco abaixo
> divergir do código. Subir qualquer versão sem atualizar este arquivo quebra o CI. O processo de
> expansão está em [`pipeline-expansao.md`](pipeline-expansao.md).

## Bloco de versões

<!-- VERSOES:INICIO -->
schema=3
content=3
sim=6
hash=1245379674
analytics=2
<!-- VERSOES:FIM -->

| Chave | Fonte | Papel |
|---|---|---|
| `schema` | `ProfileSchema.SCHEMA_VERSION` | formato do perfil; mudança exige migração e fixture |
| `content` | `TrapCatalog.CONTENT_VERSION` | conteúdo/economia; persistido no perfil como `contentVersion` (GAP-001 fechado) |
| `sim` | `Core.SIM_VERSION` | matemática da batalha; replay antigo é recusado |
| `hash` | `sim/acceptance.luau` (seed 42) | referência de determinismo do motor |
| `analytics` | `AnalyticsTypes.SCHEMA_VERSION` | taxonomia de eventos/enums do Analytics |

## Regras

1. **Fonte > bloco.** Se o código e este arquivo divergirem, o gate falha e a mudança não entra.
2. **Hash só muda com `simVersion` nova.** Se o hash mudar sem versão nova, o gate aponta a
   divergência e a mudança precisa ser registrada em
   [`spec-motor-deterministico.md`](spec-motor-deterministico.md).
3. **`STORE_NAME` não é versão de schema.** `MuralhaProfile_v1` é a chave do DataStore e continua
   `v1` com `schemaVersion = 3`; o teste real no ProfileStore/DataStore foi o Modo B de 10/11/2026
   (GAP-009 fechado).
4. **Conteúdo tem gate próprio.** `profile.contentVersion` é comparado ao catálogo no boot:
   perfil antigo é reparado (`TrapCatalog.TRAP_ALIASES`) e perfil futuro é recusado
   (`content_future`); o `WallService` não aceita perfil fora da versão do catálogo.
5. **Taxonomia está no bloco.** `AnalyticsTypes.SCHEMA_VERSION = 2` entrou no bloco `VERSOES` na
   P2 (GAP-004/008/015/016: `trap_moved`, `wall_upgraded`, `cosmetic_equipped`, `gold_spent.sink=wall`
   e coordenadas livres `x, y` no `trap_placed`/`upgrade_bought`).
6. **P2 Wave 1 (13/11/2026).** `schema=3` (slots livres, `(x, y)` step 250, `wall.level` 1..5 e
   `equipped`), `content=3` (`MAX_LEVEL=5`, `WALL_LEVELS` Nv1..5 e sink `"wall"`), `sim=5` (colocação
   livre contínua na arena, `WALL_LEVELS` e `tooClose`, preservando o hash `1793200753` na parede
   padrão seed 42) e `analytics=2`.
7. **Motor v6 (13/11/2026).** `archer` passa a mirar em área circular 360° (`omni = true`,
   `range = 2500`, `dmg = 1400`, `cd = 10`) em vez de corredor único frontal; hash de referência
   re-ancorado em `1245379674` (seed 42, `62,6%` vitória do defensor em 1.000 seeds).
