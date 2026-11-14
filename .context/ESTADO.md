# ESTADO — jogo-roblox

> Regra: este arquivo é **sobrescrito**, nunca append-only. Teto: 80 linhas. Atualizado: 14/11/2026.

## O que é
**MURALHA**: tower defense invertido + autobattler + co-op síncrono/assíncrono + campanha/bosses e
física real híbrida; mobile-first (PT-BR/EN/ES), sem avatar visível (DevEx 18+). Público 13–34.

## Fase
**P2 + Playtest v1.2 entregue (14/11/2026).** `Core v7` (6 classes de horda + 5 Bosses + 8 mutadores), `CampaignCatalog`, `ProfileSchema v4`, `CrowdKit`, `HordeKit` (`-X` corrigido s/ `Ry180` extra), `BootLoading` (`ReplicatedFirst`), `TransitionKit` (`Card 1 VS Card 2`), Thumbnail/Icon/Loading Open Cloud e `56 SFX` + `4 stems BGM`.
## Números atuais (13/11/2026)
| Métrica | Valor |
|---|---|
| tick / cap | 0,05s · 1.200 ticks (60s) |
| estado | 100% inteiro (MILLI = 1000) |
| custo por batalha | ~1,6 ms (~620 batalhas/s) |
| determinismo | hash `1245379674` (seed 42, 3 execuções) · `simVersion 7` |
| acceptance P1 | 1.000 seeds × 3 · 1.000 hashes · 62,6% defensor · ~1,6s/1.000 |
| invariantes | 19/19 (`sim/invariants.luau`) |
| contratos | perfil 23/23 · analytics 35/35 · muralha 16/16 · conteúdo 7/7 · build 17/17 · visual 16/16 · drop-in 11/11 · raid 15/15 · campanha 6/6 · i18n 7/7 |
| versões | schema 4 · content 3 · sim 7 · hash `1245379674` · analytics 2 (`docs/versoes.md`) |
| perfil | schema v4 · `contentVersion 3` · store `MuralhaProfile_v1` · migração 0/1/2/3→4 |
| analytics | contrato v2 · `trap_moved`/`wall_upgraded`/`cosmetic_equipped` · sink DataStore/Memory |
| teste de sessão | Modo A 8/8 + Modo B schema v1 8/8 (09/11) · Modo B schema v2 8/8 (10/11) |

## Pronto

- Conceito/Modos: `docs/gdd-muralha.md` v1.2 + `literatura-e-universo.md` + `skills-tiers-e-modos.md` + `campanha-bosses-e-coop-sincrono.md`.
- Economia/Catálogo/Meta: `modelo-financeiro.xlsx`, `tese-produto-e-economia.md`, `catalogo-itens-e-cosmeticos.md`, `sistemas-jogo-completo.md`.
- Evidência/Visual/Áudio: `pesquisa-tendencias-2026/jogadores/grade`, `direcao-visual-e-silhuetas.md`, `audio-musica-e-soundscape.md`, `animacoes-fisica-real-e-vfx.md`.
- Arquitetura/Runbooks: `padroes-engenharia.md` + `arquitetura-e-fluxos.md` + `plano-playtest-v1.md` + `rfcs-p2-e-fechamento-gaps.md` (`RFC-001..009`); S4–S6.1 fechadas.
- Motor: `src/shared/sim/core.luau` (v7, Arqueiro 360°, 6 classes, 5 Bosses multi-lane, 8 mutadores) + `src/shared/campaign/CampaignCatalog.luau` (5 Atos × 5 estágios).
- Muralha: `TrapCatalog.luau` (v3, `MAX_LEVEL=5`, `WALL_LEVELS`) + `WallService.luau` (`placeAt`/`move`/`upgradeWall`/`equipCosmetic`/`toBattleWall`) + `WallController`.
- Dados: `ProfileSchema.luau` (v4/campanha Normal+Nightmare/3★/marcos) + `ProfileService.luau` + `ProfileBoot.server.luau` (`23/23`).
- Analytics/i18n: `AnalyticsService`/`DataStoreSink`/`AnalyticsBoot` (v2, `35/35`) + `I18n.luau` (`77` chaves, `7/7`).
- Visual P2/Open Cloud: `VisualTheme`/`UiAssets` (Thumbnail `1920x1080`, Icon `512x512`, Backdrop `Transition`), `BootLoading` (`ReplicatedFirst`), `TransitionKit` (`Card 1 VS Card 2`), `HordeKit`/`CrowdKit`/`AmbientLife` (`-X` corrigido), `CampaignUi`, `56 SFX` + `4 stems BGM`.
- Tooling: Rokit + CLI/GUI + Forge3D 0.6.1; CI ativo; `check.sh` com `luau-lsp --platform=roblox` completo + `check-versions.py`.
- Monetização: base 2% × US$ 2; topo 4,5% × US$ 5; gate ARPDAU líquido US$ 0,005.
- Contexto: `skills/context-recovery/` (protocolo de auditoria portátil) + `BotPhantoms`/`PhantomStore` 8-slots.

## Não pronto

- QA mobile no Studio publicado sob `userId = 11966727684` (`InsertService:LoadAsset`).
- GAP-005/013/018(co-op 20 Hz)/019(F1/5 temas)/020 abertos; ver `docs/gaps.md`.

## Congelado

- Decisões do GDD: 5×5 → 7×5 por nível; cercos livres + 3 Grandes Saques; derrota só perde liga;
  `A MURALHA` / `WALLBREAKER` / `LA MURALLA`; co-op síncrono + física real híbrida desbloqueados (13/11).
- Servidor autoritativo + replay determinístico (`seed + commands[]`) + `simVersion`; hash só muda com `simVersion` novo.
- Regras dos jogadores: nenhuma unidade obrigatória; poder só por gameplay; sem loot box.
- Schema v4 (com `contentVersion 3` + `equipped` + `campaign`) + taxonomia v2: mudança só aditiva, com migração/`schema_version`.

## Próximo passo

1. Publicar place no Studio (conta `11966727684`) para QA mobile de Campanha/5 Bosses, Torcida, câmera `wall` e Mix SFX/BGM.

## Como verificar o estado em 1 minuto

```bash
source scripts/env.sh
bash scripts/doctor.sh     # estação completa
bash scripts/check.sh      # build, StyLua, luau-lsp, versões, invariantes, contratos, contexto
```
