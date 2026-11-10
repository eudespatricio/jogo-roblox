# Relatório de trial de expansão — classe/trait/raridade

- **Data:** 09/11/2026
- **Branch/commit do trial:** `trial/class-trait-rarity` · `7d53327` (branch apagada após o teste)
- **Base da main:** `62ae946`
- **Tipo:** schema + conteúdo + motor (dry run, sem merge)

> **Atualização (10/11/2026):** o GAP-007 foi fechado na S3.3 (`scripts/check-versions.py` +
> `docs/versoes.md`) e o GAP-010 foi fechado na S3.4 (schema v2 + migração neutra em
> `sim/content-contract.luau`). GAP-004/008 (classe/taxonomia v2) e GAP-009 (ProfileStore real)
> continuam abertos. O relatório abaixo preserva o estado do trial em 09/11/2026.

## 1. Escopo do trial

Implementar, em branch temporária, uma expansão **além do que existia** para provar o pipeline:

- `Cell` ganha `class`, `trait` e `rarity`;
- `ProfileSchema` v2 com migração v1→v2 e fixture antigo;
- `TrapCatalog` v2 com catálogos de classe/trait/raridade e `resolveDamagePct`;
- `WallService` valida/persiste variantes e falha fechado para id desconhecido;
- `Core` aceita um `dmgPct` resolvido (100 = neutro) e sobe para `simVersion 3`;
- contratos de perfil, muralha, acceptance e analytics re-ancorados.

Fora do escopo: UI, `BattleLog`, taxonomia v2, deploy real.

## 2. Versões

| Versão | Antes | Depois |
|---|---|---|
| `ProfileSchema.SCHEMA_VERSION` | 1 | **2** |
| `TrapCatalog.CONTENT_VERSION` | 1 | **2** |
| `Core.SIM_VERSION` | 2 | **3** |

## 3. Arquivos tocados

| Área | Arquivos | O que mudou |
|---|---|---|
| schema | `ProfileSchema.luau` | campos, validação, sanitização, migração 1→2, fixture v1 |
| catálogo | `TrapCatalog.luau` | 2 classes, 3 traits, 2 raridades, resolve de dano |
| serviço | `WallService.luau` | valida variantes, persiste, calcula `damagePct`, guarda |
| motor | `core.luau` | `dmgPct` por trap, `simVersion 3` |
| testes | `profile-contract`, `walls-contract`, `acceptance`, `analytics-contract`, `invariants`, `fixtures/profile-v1` | 20/13/6/16/12 checagens |
| docs | — | **não atualizados no trial** (ver GAP-007) |

## 4. Evidências

| Prova | Resultado |
|---|---|
| hash base (seed 42) | `2489780106` |
| hash com `dmgPct=100` (neutro) | `2489780106` — **idêntico** |
| hash com `dmgPct=121` | `2557415938` — determinístico |
| migração v1→v2 | `schema=2`, `class=artillery`, `trait=none`, `rarity=common` |
| default neutro | `WallService` coloca com `damagePct=100`; variante `121` |
| perfil inválido | `class=wizard` recusada no boot |
| invariantes | 12/12 |
| acceptance | 6/6 (inclui variante) |
| contrato de perfil | 20/20 |
| contrato de analytics | 16/16 |
| contrato de muralha | 13/13 |
| `doctor.sh` / `check.sh` | RC=0 / RC=0 |
| `scan_repo.py --check` | 76/80 · 59/60 · 19/40 |

## 5. O que o teste ensinou

1. **Default de migração tem que ser neutro.** A primeira versão usou `class = "vanguard"` (110% de
   dano) como default. Isso teria buffado silenciosamente **todas** as muralhas antigas em 10% na
   migração. Trocamos para `artillery` (100%); o hash neutro continuou `2489780106`. Regra nova:
   default de migração = comportamento antigo, nunca bônus.
2. **O CI não detecta doc velho.** O `check.sh` passou verde com `check.sh` ainda imprimindo
   “schema v1”/“motor v2” e a spec desatualizada. Isso é GAP-007.
3. **Analytics fica cego para variantes.** `trap_placed`/`upgrade_bought` não carregam
   class/trait/rarity; a taxonomia v1 é congelada. Isso é GAP-008.
4. **O teste real de ProfileStore/Studio não existe para schema v2.** O contrato usa store fake;
   `STORE_NAME` continua `MuralhaProfile_v1` com `schemaVersion=2`. Isso é GAP-009.
5. **Default neutro não é automaticamente testado.** O perfil migra com os defaults, mas não há um
   teste que compare o hash de uma parede v1 migrada com o comportamento anterior. Isso é GAP-010.
6. **`MIGRATIONS[1]` normaliza para o schema atual** em vez de ser um diff explícito v1→v2. Funciona,
   mas mascara o que mudou; vale um padrão de migração mais explícito.

## 6. Veredito

**O pipeline funcionou de ponta a ponta no código real.** Schema v2, catálogo, serviço, motor,
contratos e hash foram exercitados; `check.sh` e `doctor.sh` verdes. O trial também provou o valor
do teste: o default bônus teria passado se não fosse a revisão; o CI não pegaria.

**Não é seguro adicionar classe/trait/raridade em produção ainda.** Antes do primeiro merge real de
conteúdo, fechar GAP-001/002/003 (versão/migração/engine) e GAP-007/008/009/010 (docs, analytics,
ProfileStore real, default neutro). A S4 pode seguir porque usa o catálogo atual; a expansão de
conteúdo não.

**Limpeza:** branch `trial/class-trait-rarity` removida; `main` limpa em `62ae946`. O patch de
referência está em [`../tools/expansion-test/examples/class-trait-rarity.patch`](../tools/expansion-test/examples/class-trait-rarity.patch)
(10 arquivos, +358/−41) e o kit reutilizável em [`../tools/expansion-test/README.md`](../tools/expansion-test/README.md).
