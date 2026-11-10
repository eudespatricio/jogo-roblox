# Versões — fonte executável x documentação

> **Gate:** `python3 scripts/check-versions.py` roda no `scripts/check.sh` e falha se o bloco abaixo
> divergir do código. Subir qualquer versão sem atualizar este arquivo quebra o CI. O processo de
> expansão está em [`pipeline-expansao.md`](pipeline-expansao.md).

## Bloco de versões

<!-- VERSOES:INICIO -->
schema=1
content=1
sim=2
hash=2489780106
<!-- VERSOES:FIM -->

| Chave | Fonte | Papel |
|---|---|---|
| `schema` | `ProfileSchema.SCHEMA_VERSION` | formato do perfil; mudança exige migração e fixture |
| `content` | `TrapCatalog.CONTENT_VERSION` | conteúdo/economia; ainda não persistido (GAP-001) |
| `sim` | `Core.SIM_VERSION` | matemática da batalha; replay antigo é recusado |
| `hash` | `sim/acceptance.luau` (seed 42) | referência de determinismo do motor |

## Regras

1. **Fonte > bloco.** Se o código e este arquivo divergirem, o gate falha e a mudança não entra.
2. **Hash só muda com `simVersion` nova.** Se o hash mudar sem versão nova, o gate aponta a
   divergência e a mudança precisa ser registrada em
   [`spec-motor-deterministico.md`](spec-motor-deterministico.md).
3. **`STORE_NAME` não é versão de schema.** `MuralhaProfile_v1` é a chave do DataStore e continua
   `v1` mesmo com `schemaVersion` novo (GAP-009).
4. **Taxonomia é separada.** `AnalyticsTypes.SCHEMA_VERSION = 1` é a taxonomia congelada; mudar
   evento/enum exige taxonomia v2 e não entra neste bloco.
