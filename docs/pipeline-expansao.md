# Pipeline de expansão — conteúdo e features

> **Regra de ouro:** toda expansão é uma mudança **versionada, testada, documentada e reversível**.
> O mesmo pacote de arquivos + as mesmas versões (`SCHEMA_VERSION`, `CONTENT_VERSION`, `simVersion`)
> precisam produzir o mesmo resultado. Se um passo só existe na cabeça de quem fez, o pipeline não é
> reproduzível.

---

## 1. As três versões (não confundir)

| Versão | Onde vive | Muda quando | Efeito |
|---|---|---|---|
| `ProfileSchema.SCHEMA_VERSION` | `src/shared/data/ProfileSchema.luau` | muda o **formato** do perfil (campo novo, tipo de célula, classe/trait) | migração `MIGRATIONS[n]`, fixture, contrato de perfil; servidor antigo recusa `schema_future` |
| `TrapCatalog.CONTENT_VERSION` | `src/shared/data/TrapCatalog.luau` | muda **conteúdo/economia** (trap, custo, desbloqueio, nível) | catálogo + docs + contrato; hoje ainda **não persistido** (ver GAP-001) |
| `Core.SIM_VERSION` | `src/shared/sim/core.luau` | muda a **matemática** da batalha (stats, comportamento, RNG, escala de nível) | re-ancorar hash/acceptance/spec; replay antigo não paga recompensa |

Também existe `AnalyticsTypes.SCHEMA_VERSION` (taxonomia v1, congelada). Mudar enum/evento exige
taxonomia **v2** e contrato; não é uma expansão de catálogo.

O bloco canônico de versões está em [`versoes.md`](versoes.md): `scripts/check-versions.py` roda no
`check.sh` e falha se `SCHEMA_VERSION`, `CONTENT_VERSION`, `SIM_VERSION` ou o hash de referência
divergirem do código (GAP-007 fechado na S3.3).

**Regra de replay:** qualquer conteúdo que possa aparecer em um `BattleLog` precisa ser reproduzível
com `(seed, simVersion, wallSpec, waveSpec)`. Enquanto `CONTENT_VERSION` não estiver persistida,
**tipo novo de armadilha = `simVersion` nova** (mesmo que o hash da seed 42 não mude).

---

## 2. Matriz de decisão

| Mudança | Schema | Content | Sim | Taxonomia | Observação |
|---|---|---|---|---|---|
| custo/desbloqueio de trap existente | — | **+1** | — | — | só economia; replay não muda |
| nível máximo (3→4/5) | — | **+1** | — | — | `MAX_LEVEL` + contrato; schema/core já aceitam 5 |
| trap nova que reusa mecânica existente | — | **+1** | **+1** | — | stats/ID novo; replay precisa da versão |
| trap nova com comportamento novo | — | **+1** | **+1** | — | stats + lógica + hash/acceptance |
| classe/trait/raridade na célula | **+1** | **+1** | **+1** | — | `Cell` ganha campo; migração 0→1→2 |
| item cosmético | — | **+1** | — | — | `cosmetics[id]`; não entra no replay |
| evento/sazonalidade | talvez | **+1** | talvez | talvez | exige flags/calendário (GAP-005) |
| evento analítico novo | — | — | — | **v2** | taxonomia congelada; contrato junto |
| fonte/sink de ouro novo | — | **+1** | — | **v2** | enum de `gold_earned`/`gold_spent` |

---

## 3. Passo a passo (copiar em toda expansão)

1. **RFC curta** (1 página): problema, jogador, economia, versões afetadas, rollback. Template na §5.
2. **Dados:** editar `TrapCatalog` (ou manifest futuro); `CONTENT_VERSION += 1`; atualizar
   `docs/economia-muralha.md`.
3. **Motor:** se a mudança aparece em batalha, editar `Core.TRAP`/`TRAP_NAMES` e decidir
   `SIM_VERSION`; re-ancorar `sim/acceptance.luau`, `docs/spec-motor-deterministico.md` e hash.
4. **Schema:** se o formato do perfil mudou, `SCHEMA_VERSION += 1`, `MIGRATIONS[n]`, fixture
   `sim/fixtures/profile-v*.luau` e `sim/profile-contract.luau`; nunca renomear campo sem migração.
5. **Migração de conteúdo:** se renomeou/removeu `trap_id`, registrar em
   `TrapCatalog.TRAP_ALIASES` (antigo→novo), subir `CONTENT_VERSION` e testar perfil antigo em
   `sim/content-contract.luau`. Sem alias, **não remover**: o perfil falha fechado. Default de
   campo novo deve ser **neutro** (preserva HP/dano/hash antigos); bônus silencioso é bug.
6. **Testes:** `sim/invariants.luau`, `sim/acceptance.luau`, `sim/walls-contract.luau`,
   `sim/profile-contract.luau`, `sim/analytics-contract.luau`; adicionar caso novo e caso de
   regressão. O contrato da muralha pina `TRAP_IDS`, custos e fontes/sinks — atualizar de propósito.
7. **Docs:** este pipeline, `economia-muralha.md`, `spec`, `versoes.md`, `ESTADO`/`MAPA`/`CONTINUAR`, `gaps.md`.
8. **Gate:** `bash scripts/check.sh` (build, StyLua, luau-lsp, versões docs x fonte, invariantes,
   acceptance, contratos, migração neutra, sourcemap, tetos) + CI verde.
9. **Rollout:** publicar; verificar servidor antigo x novo; se `CONTENT_VERSION`/`schemaVersion`
   mudou, garantir que servidor antigo **recusa com mensagem** ou migra — não simula conteúdo que
   não conhece. Plano de rollback na RFC.
10. **Fechamento:** uma linha `GAP:` no handoff; gaps abertos em `docs/gaps.md`; registrar versão
    publicada.

---

## 4. Reprodutibilidade — o que o CI garante e o que não garante

Garantido hoje:

- build determinístico do place (`rojo build`);
- hash/acceptance do motor (1.000 seeds × 3);
- paridade `TrapCatalog.TRAPS == Core.TRAP == Core.TRAP_NAMES`;
- cada tipo do catálogo é aceito pelo motor;
- `TRAP_IDS`, custos, fontes e sinks pinados no contrato;
- perfil inválido (trap desconhecida, >N, nível acima do cap) falha fechado no `WallService`;
- `contentVersion` persistido no perfil e comparado ao catálogo no boot/`WallService`
  (GAP-001 fechado na S3.4);
- rename/repair de `trap_id` por `TrapCatalog.TRAP_ALIASES`, com `content_future` recusado
  (GAP-002 fechado; remoção sem alias continua falhando fechado);
- 5º tipo no motor/catálogo com `SIM_VERSION++` e contrato de paridade (política do GAP-003);
- migração neutra de schema/conteúdo testada por hash (GAP-010 fechado na S3.4);
- eventos da muralha validados contra a taxonomia v1;
- bloco de versões (`docs/versoes.md`) comparado ao código pelo `scripts/check-versions.py`;
- tetos de contexto.

Não garantido ainda (ver `docs/gaps.md`):

- `CONTENT_VERSION` no `BattleLog` (S6) — hoje só o perfil carrega `contentVersion`;
- remoção de trap sem alias/substituto: falha fechado, não apaga a célula;
- stats do motor fora do código (data-driven) — a política atual é `SIM_VERSION++` por tipo;
- classes/traits/raridades — exigem schema v3 + migração + taxonomia v2 (GAP-004/008);
- flags/calendário para eventos semanais (GAP-005);
- rollback de conteúdo em servidores antigos;
- docs fora do bloco de versões ainda podem envelhecer sem o CI reclamar;
- ProfileStore/Studio real com schema v2 (GAP-009).

---

## 5. Template de RFC de expansão

```md
# RFC — <nome da expansão>

- **Data / responsável:**
- **Tipo:** conteúdo | economia | motor | schema | evento | cosmético
- **Versões:** schema __ → __ · content __ → __ · sim __ → __
- **Jogador:** o que muda na sessão? qual métrica deve subir?
- **Economia:** custo, recompensa, efeito no gold; nenhuma venda de poder.
- **Replay:** entra no BattleLog? como o servidor antigo recusa/migra?
- **Migração:** passo a passo; fixture antigo e novo.
- **Testes:** casos novos + regressão; hash/acceptance.
- **Rollout / rollback:** como publicar, como voltar, o que acontece com perfis já escritos.
- **GAP:** linha de gap aberto (ou "nenhum").
```

## 6. Template de migração de conteúdo

```lua
-- MIGRATIONS[n]: <de> -> <para>
-- 1) mapa de ids antigos -> novos (ou remoção com compensação)
-- 2) preservar level/gold quando possível
-- 3) rodar sanitizeV1/validate no fim
-- 4) fixture antigo em sim/fixtures/profile-v<n>.luau
-- 5) teste de ida e volta em sim/profile-contract.luau
```

## 7. Fechamento de P/S: a linha GAP

Toda fase P ou fatia S termina com **uma linha** no handoff, no formato:

```text
GAP: <id(s)> · <resumo> · <risco> · <gatilho> · ver docs/gaps.md
```

Se não houver gap: `GAP: nenhum`. Gap aberto ganha uma linha em `docs/gaps.md` com o mesmo ID.
O `CONTINUAR.md` não fecha uma fatia sem essa linha, e o `scripts/check.sh` falha se ela sumir.

## 8. Lições do primeiro trial (09/11/2026)

O trial de classe/trait/raridade está em
[`expansion-test-2026-11-10.md`](expansion-test-2026-11-10.md), com o kit reutilizável em
[`../tools/expansion-test/README.md`](../tools/expansion-test/README.md). O que ele ensinou:

1. **Default de migração tem que ser neutro.** `vanguard` como default teria dado +10% de dano
silencioso em toda parede antiga. `artillery` (100%) preservou o hash.
2. **CI verde não prova docs atualizados.** O trial passou com labels “schema v1/motor v2”; a S3.3
   fechou o GAP-007 com `scripts/check-versions.py` + `docs/versoes.md`. Docs fora do bloco ainda
   podem envelhecer.
3. **Variantes precisam de decisão de analytics.** Eventos v1 não carregam classe/trait/raridade. GAP-008.
4. **Teste com ProfileStore real é obrigatório** antes de deploy de schema. GAP-009.
5. **Default neutro precisa de teste de hash antigo x migrado**, não só de campo preenchido. GAP-010.
