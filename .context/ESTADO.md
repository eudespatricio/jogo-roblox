# ESTADO — jogo-roblox

> Regra: este arquivo é **sobrescrito**, nunca append-only. Teto: 80 linhas. Atualizado: 16/11/2026.

## O que é
**MURALHA**: tower defense invertido + autobattler + co-op síncrono/assíncrono + campanha/bosses e
física real híbrida; mobile-first (PT-BR/EN/ES), sem avatar visível (DevEx 18+). Público 13–34.

## Fase
**P2 + Playtest v1.9 High-Budget AA 3D, Voronoi PBR & Grid8x8 VFX (16/11/2026).** `211` assets publicados no Open Cloud sob `forge3d 0.9.0` (`spec@6` / `manifest@6`, `perfil: roblox-aa-80`, `Lighting.Technology = Future`, Gate G1–G11 verdes): `97` malhas 3D AA (`556.066` tris catálogo · `~441k` tris em combate intenso `45 mobs + Boss`), `strip_embedded_textures=true`, `25` presets `SurfaceAppearances.model.json` pré-bakeados para Rojo (zero `PluginSecurity` em runtime) e `14` texturas VFX (`Grid8x8`/`Grid4x4`/decals/beams/`VfxVolumeWave`, `visual-contract` `33/33`).
## Números atuais (16/11/2026)
| Métrica | Valor |
|---|---|
| tick / cap | 0,05s · 1.200 ticks (60s) |
| estado | 100% inteiro (MILLI = 1000) |
| custo por batalha | ~1,6 ms (~620 batalhas/s) |
| determinismo | hash `1245379674` (seed 42, 3 execuções) · `simVersion 8` |
| acceptance P1 | 1.000 seeds × 3 · 1.000 hashes · 62,6% defensor · ~1,6s/1.000 |
| invariantes | 20/20 (`sim/invariants.luau`) |
| contratos | perfil 25/25 · analytics 36/36 · muralha 16/16 · conteúdo 7/7 · build 17/17 · visual 33/33 · drop-in 11/11 · raid 17/17 · campanha 6/6 · deck 5/5 · pos-partida 7/7 · i18n 7/7 |
| versões | schema 6 · content 3 · sim 8 · hash `1245379674` · analytics 2 (`docs/versoes.md`) |
| perfil | schema v6 · `contentVersion 3` · store `MuralhaProfile_v1` · migração 0..5→6 |
| analytics | contrato v2 (`40` eventos) · `ftue_step`/`ftue_skip`/`revenge_started` · sink DataStore/Memory |
| teste de sessão | Modo A 8/8 + Modo B schema v1 8/8 (09/11) · Modo B schema v2 8/8 (10/11) |

## Pronto

- Conceito/Modos: `docs/gdd-muralha.md` v1.2 + `literatura-e-universo.md` + `skills-tiers-e-modos.md` + `campanha-bosses-e-coop-sincrono.md`.
- Economia/Catálogo/Meta: `modelo-financeiro.xlsx`, `tese-produto-e-economia.md`, `catalogo-itens-e-cosmeticos.md`, `sistemas-jogo-completo.md`.
- Evidência/Visual/Áudio: `pesquisa-tendencias-2026/jogadores/grade`, `direcao-visual-e-silhuetas.md`, `audio-musica-e-soundscape.md`, `animacoes-fisica-real-e-vfx.md`.
- Arquitetura/Runbooks: `padroes-engenharia.md` + `arquitetura-e-fluxos.md` + `plano-playtest-v1.md` + `rfcs-p2-e-fechamento-gaps.md` (`RFC-001..009`); S4–S6.1 fechadas.
- Motor & Pós-Partida: `src/shared/sim/core.luau` (v8, voadores, campeões, telemetria read-only, 5 Bosses, 8 mutadores), `DeckCatalog`, `CampaignCatalog` (25 estágios) e `PostMatchReport`.
- Muralha & FTUE: `TrapCatalog.luau` (v3, `totalGoldInvested`, `MAX_LEVEL=5`) + `WallService.luau` + `WallController` + `FtueLogic`/`FtueService`/`FtueController`.
- Dados & Inbox: `ProfileSchema.luau` (v6: `ftue`, `battleHistory`, `revengeCooldowns`) + `ProfileService.luau` + `DefenseInboxStore.luau` (`25/25`, `7/7`).
- Analytics/i18n: `AnalyticsService`/`DataStoreSink`/`AnalyticsBoot` (v2, `36/36`, `40` eventos) + `I18n.luau` (`161` chaves, `7/7`).
- Visual P2/Open Cloud: `211` assets Open Cloud (`97` malhas 3D AA até `17.680` tris + `100` mapas PBR em `SurfaceAppearances.model.json`/`PbrAssets` + `14` texturas VFX `VfxAssets`), `Lighting.Technology = Future`, `HordeKit`/`TrapKit`/`CrowdKit`/`AmbientLife`, `Vfx` (`Grid8x8`/`4×4`, `LightningArcBeam`, `Decal` + `VfxVolumeWave` Mid/High), `UiKit`/`BuildLayout`, `PostMatchUi`/`BattleLogUi`/`FtueUi`/`DeckUi`/`CampaignUi`, `TransitionKit`, 87 cues Open Cloud (`33/33`).
- Tooling: Rokit + CLI/GUI + Forge3D `0.9.0` (`spec@6`/`manifest@6`, `roblox-aa-80`); CI ativo; `check.sh` com `luau-lsp --platform=roblox` completo + `check-versions.py`.
- Monetização: base 2% × US$ 2; topo 4,5% × US$ 5; gate ARPDAU líquido US$ 0,005.
- Contexto: `skills/context-recovery/` (protocolo de auditoria portátil) + `BotPhantoms`/`PhantomStore` 8-slots.

## Não pronto

- QA mobile no Studio publicado sob `userId = 11966727684` (`InsertService:LoadAsset`).
- GAP-005/013/018(co-op 20 Hz)/019(F1/5 temas)/020(loja/passe/badges/settings) abertos; ver `docs/gaps.md`.

## Congelado

- Decisões do GDD: 5×5 → 7×5 por nível; cercos livres + 3 Grandes Saques; derrota só perde liga;
  `A MURALHA` / `WALLBREAKER` / `LA MURALLA`; co-op síncrono + física real híbrida desbloqueados (13/11).
- Servidor autoritativo + replay determinístico (`seed + commands[]`) + `simVersion`; hash só muda com `simVersion` novo.
- Regras dos jogadores: nenhuma unidade obrigatória; poder só por gameplay; sem loot box.
- Schema v6 (com `contentVersion 3` + `equipped` + `campaign` + `horde` + `ftue` + `battleHistory`/`revengeCooldowns`) + taxonomia v2: mudança só aditiva.

## Próximo passo

1. Publicar place no Studio (conta `11966727684`) para QA mobile de Pós-Partida, BattleLog/Vingança, FTUE `0..6`, DeckUi e Campanha/5 Bosses.

## Como verificar o estado em 1 minuto

```bash
source scripts/env.sh
bash scripts/doctor.sh     # estação completa
bash scripts/check.sh      # build, StyLua, luau-lsp, versões, invariantes, contratos, contexto
```
