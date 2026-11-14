# ESTADO — jogo-roblox

> Regra: este arquivo é **sobrescrito**, nunca append-only. Teto: 80 linhas. Atualizado: 13/11/2026.

## O que é
**MURALHA**: tower defense invertido + autobattler + co-op síncrono/assíncrono + campanha/bosses e
física real híbrida; mobile-first (PT-BR/EN/ES), sem avatar visível (DevEx 18+). Público 13–34.

## Fase
**P2 Completa + Playtest v1.1 entregue (13/11/2026).** `Core v6` (Arqueiro circular 360°), `TrapCatalog v3`, `ProfileSchema v3`, `DEFEND + ATTACK` (própria muralha vs rival), luta em tempo real `1×..4×` (`60s` + `REPLAY 20s`), horda alinhada para a muralha + vale contínuo c/ fauna e 97 assets Open Cloud (55 malhas + 42 áudios). **GAP-004/008/015/016 fechados.**
## Números atuais (13/11/2026)
| Métrica | Valor |
|---|---|
| tick / cap | 0,05s · 1.200 ticks (60s) |
| estado | 100% inteiro (MILLI = 1000) |
| custo por batalha | ~1,6 ms (~620 batalhas/s) |
| determinismo | hash `1245379674` (seed 42, 3 execuções) · `simVersion 6` |
| acceptance P1 | 1.000 seeds × 3 · 1.000 hashes · 62,6% defensor · ~1,6s/1.000 |
| invariantes | 16/16 (`sim/invariants.luau`) |
| contratos | perfil 22/22 · analytics 35/35 · muralha 16/16 · conteúdo 7/7 · build 17/17 · visual 15/15 · drop-in 11/11 · raid 15/15 · i18n 7/7 |
| versões | schema 3 · content 3 · sim 6 · hash `1245379674` · analytics 2 (`docs/versoes.md`) |
| perfil | schema v3 · `contentVersion 3` · store `MuralhaProfile_v1` · migração 0→3/1→3/2→3 |
| analytics | contrato v2 · `trap_moved`/`wall_upgraded`/`cosmetic_equipped` · sink DataStore/Memory |
| teste de sessão | Modo A 8/8 + Modo B schema v1 8/8 (09/11) · Modo B schema v2 8/8 (10/11) |

## Pronto

- Conceito/Modos: `docs/gdd-muralha.md` v1.2 + `literatura-e-universo.md` + `skills-tiers-e-modos.md` + `campanha-bosses-e-coop-sincrono.md`.
- Economia/Catálogo/Meta: `modelo-financeiro.xlsx`, `tese-produto-e-economia.md`, `catalogo-itens-e-cosmeticos.md`, `sistemas-jogo-completo.md`.
- Evidência/Visual/Áudio: `pesquisa-tendencias-2026/jogadores/grade`, `direcao-visual-e-silhuetas.md`, `audio-musica-e-soundscape.md`, `animacoes-fisica-real-e-vfx.md`.
- Arquitetura/Runbooks: `padroes-engenharia.md` + `arquitetura-e-fluxos.md` + `plano-playtest-v1.md` + `rfcs-p2-e-fechamento-gaps.md` (`RFC-001..009`); S4–S6.1 fechadas.
- Motor: `src/shared/sim/core.luau` (v6, Arqueiro 360°, colocação contínua `ARENA`, `WALL_LEVELS`, `tooClose`) + `sim/`.
- Muralha: `TrapCatalog.luau` (v3, `MAX_LEVEL=5`, `WALL_LEVELS`) + `WallService.luau` (`placeAt`/`move`/`upgradeWall`/`equipCosmetic`/`toBattleWall`) + `WallController`.
- Dados: `ProfileSchema.luau` (v3/`equipped`/slots) + `ProfileService.luau` + `ProfileBoot.server.luau` (`22/22`).
- Analytics/i18n: `AnalyticsService`/`DataStoreSink`/`AnalyticsBoot` (v2, `35/35`) + `I18n.luau` (`62` chaves, `7/7`).
- Visual P2/Open Cloud: `VisualTheme`/`ArenaVisual` (`ValleyBlendApron` + `PROP_*` + tochas VFX)/`Backdrop`/`AmbientLife` (`55` malhas + `39` SFX + `3` stems BGM), HUD mobile periférico (`DeviceSafeInsets` + `TopbarInset`), `visual-contract`.
- Tooling: Rokit + CLI/GUI; CI ativo; `check.sh` com `luau-lsp --platform=roblox` completo + `check-versions.py`.
- Monetização: base 2% × US$ 2; topo 4,5% × US$ 5; gate ARPDAU líquido US$ 0,005.
- Contexto: `skills/context-recovery/` (protocolo de auditoria portátil) + `BotPhantoms`/`PhantomStore` 8-slots.

## Não pronto

- QA mobile no Studio publicado sob `userId = 11966727684` (`InsertService:LoadAsset`).
- GAP-005/013/018/019(F1)/020 abertos (`GAP-004/008/015/016` fechados); ver `docs/gaps.md`.

## Congelado

- Decisões do GDD: 5×5 → 7×5 por nível; cercos livres + 3 Grandes Saques; derrota só perde liga;
  `A MURALHA` / `WALLBREAKER` / `LA MURALLA`; co-op síncrono + física real híbrida desbloqueados (13/11).
- Servidor autoritativo + replay determinístico (`seed + commands[]`) + `simVersion`; hash só muda com `simVersion` novo.
- Regras dos jogadores: nenhuma unidade obrigatória; poder só por gameplay; sem loot box.
- Schema v3 (com `contentVersion 3` + `equipped`) + taxonomia v2: mudança só aditiva, com migração/`schema_version`.

## Próximo passo

1. Publicar place no Studio (conta `11966727684`) para QA mobile e decidir início da Campanha/Bosses (`GAP-018`).

## Como verificar o estado em 1 minuto

```bash
source scripts/env.sh
bash scripts/doctor.sh     # estação completa
bash scripts/check.sh      # build, StyLua, luau-lsp, versões, invariantes, contratos, contexto
```
