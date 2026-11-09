# HANDOVER — jogo-roblox

> Artefato de transição entre janelas. Base: `master` @ `a88a524` (09/11/2026).
> **Sessão nova?** Leia `AGENTS.md` e `.context/ESTADO.md` primeiro; este arquivo é o histórico +
> próximos passos. Quando a nova janela absorver tudo, este arquivo pode ser apagado.

---

## 1. Onde estamos

**Fase: pré-P0.** Nenhum código de produção do jogo. O que existe é conceito aprovado, motor
determinístico provado em `sim/` e o protótipo legado de moedas em `src/` (não é o jogo).

**Produto:** MURALHA — tower defense invertido + autobattler assíncrono, mobile-first, **sem avatar
visível** (habilita DevEx 18+ e corta custo de arte). O jogador monta a muralha, outros atacam
enquanto ele está offline, e um replay determinístico de 8s mostra o que aconteceu — com botão de
gravar clipe via `CaptureService`.

**Equipe:** 1 humano (direção, cena, game feel, QA) + 2 agentes (motor/CI e sistemas/economia).
Divisão de tarefas **não foi executada**; P0 não foi autorizada.

---

## 2. Números verificados (não reinventar)

| Métrica | Valor |
|---|---|
| tick / cap | 0,05 s · 1.200 ticks (60 s) |
| estado | 100% inteiro (`MILLI = 1000`) |
| custo por batalha | 1,28 ms (~780/s) no Luau CLI |
| determinismo | hash `668061367` (seed 42, 3 execuções) |
| 500 seeds | 500 hashes distintos · 64,8% vitória do defensor |
| invariantes | **10/10** (`sim/invariants.luau`) |
| docs | 9 arquivos |
| contexto residente | ESTADO 60/80 · MAPA 35/60 · REJEITADOS 16/40 |
| arquivos rastreados | 34 |

---

## 3. Artefatos (o que já existe)

| Caminho | Conteúdo |
|---|---|
| `docs/gdd-muralha.md` | GDD v1.1: loop, drop-in de 5s, modos, economia, fases, decisões 1–5 |
| `docs/spec-motor-deterministico.md` | contrato do motor, replay, clipe/CaptureService, anti-cheat, auditorias |
| `docs/padroes-engenharia.md` | regras com fonte oficial + tooling fechado + CI |
| `docs/pesquisa-tendencias-2026.md` | mercado, gêneros, algoritmo 2025/2026 |
| `docs/pesquisa-jogadores.md` | 9 clusters de reclamação + 10 regras derivadas |
| `docs/tese-produto-e-economia.md` | economia unitária, cenários, scorecard de conceitos |
| `docs/modelo-financeiro.xlsx` | modelo editável (Premissas, Cenários, Metas, Sensibilidade) |
| `docs/referencias-tower-defense.md` | jogos/vídeos para estudar, com o que observar |
| `docs/auditoria/CONTRADICOES.md` | **temporário**: 7 resolvidas + 2 abertas (Q1/Q2) |
| `sim/core.luau` | motor: RNG uint32, mul32/add32, Battle |
| `sim/poc.luau` | benchmark (determinismo, perf, balanço) |
| `sim/invariants.luau` | oráculo executável (10 checagens; falha o processo) |
| `sim/audit-bit32.luau`, `audit-mul32.luau` | evidência das auditorias de aritmética |
| `src/**` | protótipo legado de moedas (Rojo) — não usar como base |
| `skills/context-recovery/` | protocolo de auditoria + `scan_repo.py` + templates |
| `.context/ESTADO|MAPA|REJEITADOS.md` | contexto residente com teto de linhas |
| `AGENTS.md` | regras para qualquer agente |

---

## 4. Decisões fechadas (não reabrir sem condição)

- **Grade 5×5 no MVP**, expansível para 7×5 no nível 5 (dado no save, não código novo).
- **Cercos livres + 3 Grandes Saques/dia** (sem timer duro; economia controlada pelo loot).
- **Derrota perde só pontos de liga** (nunca nível de armadilha).
- **Nome localizado:** `A MURALHA` (PT-BR) · `WALLBREAKER` (EN).
- **Co-op na P3** (MVP solo + fantasma assíncrono + replay).
- **Servidor autoritativo**, replay por seed, `simVersion` obrigatório.
- **Tooling:** Rokit (Rojo 7.7.1, StyLua 2.6.0, Selene 0.32.0, Luau 0.746), GitHub Actions,
  ProfileStore vendorizado sob wrapper com schema versionado.
- **10 regras dos jogadores:** nenhuma unidade obrigatória; poder só por gameplay; sem loot box;
  solo primeiro; ninguém depende de presença; replay do passado; relatório de derrota; mobile alvo;
  quick chat no MVP; odds nunca escondidas.

---

## 5. Em aberto (precisa de decisão humana)

### Q1 — protótipo de moedas em `src/**`
Apagar na P1 (recomendado; fica no histórico do git) ou manter como cena de teste de pipeline?

### Q2 — grade de produção
Confirmar **5 colunas × 5 linhas (25 células)**, armadilhas por célula, 5 lanes de caminhada
(várias armadilhas por lane) — o PoC usa 1 por lane como recorte. Recomendado: sim.

### Lacunas ainda não documentadas (não bloqueiam P0; bloqueiam P1/P3)

| Lacuna | Bloqueia |
|---|---|
| Direção de arte/áudio (só parágrafo no GDD) | P1 |
| Protocolo de playtest com 5 pessoas | P2 |
| Taxonomia de analytics (só exemplo na spec) | P2 |
| Plano de marketing/criadores | P3 |
| Localização PT/EN/ES + metadados | publicação |
| Compliance (privacidade, idade, chat) | publicação |
| Custo de servidor/capacidade | escala |
| Checagem de nome/trademark (`WALLBREAKER`) | publicação |

---

## 6. Próximos passos (nesta ordem)

1. **Responder Q1 e Q2** → apagar `docs/auditoria/CONTRADICOES.md` e registrar a decisão no GDD
   (design) ou em `.context/REJEITADOS.md` (descarte).
2. **Taxonomia de analytics** (sugestão): fechar os eventos e propriedades antes do P0, porque o
   motor precisa emiti-los.
3. **P0, somente com autorização explícita:**
   - congelar interfaces (`BattleSpec`, `BattleResult`, `simVersion`);
   - portar `sim/core.luau` → `src/shared/sim/{Types,Rng,Mul32,Battle}.luau`;
   - CI (`.github/workflows/ci.yml`) com StyLua, Selene, `luau-analyze` e `sim/invariants.luau`;
   - `ProfileSchema` v1 + wrapper ProfileStore (com `Mock` no Studio);
   - cena 5×5 no Studio (board, câmera fixa, placeholders).

---

## 7. Como verificar em 1 minuto

```powershell
.\.tools\luau\luau.exe sim\invariants.luau         # deve imprimir 10/10
.\.tools\luau\luau.exe sim\poc.luau                # hash 668061367 na seed 42
python skills\context-recovery\scan_repo.py --root . --check
python skills\context-recovery\scan_repo.py --root . --ast .tools\luau\luau-ast.exe
```

Se `.tools/` sumiu: `rokit install` (versões em `rokit.toml`).

---

## 8. Armadilhas (já custaram tempo)

1. **`src/**` é legado.** Não use `CoinService` como base.
2. **Não edite `sim/core.luau` sem rodar `sim/invariants.luau`.** Hash e balanço quebram silencioso.
3. **Mudou a matemática → suba `simVersion`.** Replay antigo não pode pagar recompensa.
4. **`bit32` só aceita `[0, 2^32)`.** Use `add32`/`mul32`; nunca `band` em double grande.
5. **`bit32.band(7,2e16)` retorna lixo** (1473511424) — não é módulo.
6. **Doc mais velho que o código mente.** Rode a radiografia antes de confiar em README/tese.
7. **PoC ≠ arquitetura.** 1 armadilha por lane é recorte, não design final.
8. **Não transforme invariantes em markdown.** Regra verificável vira teste; o resto vira pergunta.
9. **Teto de contexto é rígido.** Se estourar, corte — não expanda o teto.

---

## 9. Histórico compacto desta janela

| Commit | Entrega |
|---|---|
| `e8471ed` | projeto Rojo + protótipo de moedas (pipeline validado) |
| `bdca85a` / `1804d14` | correções de build/README do protótipo |
| `9ec79fd` | motor v2 inteiro (`mul32`/`add32`, 1.200 ticks), decisões 1–5 no GDD |
| `a98c45b` | pesquisa de jogadores + padrões de engenharia com fontes |
| `ec039d7` | tooling fechado, clipe via CaptureService, `mul32` endurecido |
| `369687c` | context-recovery: radiografia, invariantes executáveis, contexto residente |
| `a88a524` | referências de tower defense para estudo em vídeo |

Pesquisa de mercado/economia e o GDD original vieram antes (`pesquisa-tendencias`, `tese-produto`,
`modelo-financeiro`).

---

## 10. O que não fazer

- Não iniciar P0/P1 sem autorização explícita do diretor.
- Não reabrir `REJEITADOS.md` sem a condição objetiva listada.
- Não copiar o TDS (é referência de falha e escala, não de design).
- Não criar mais documentos sem teto e sem dono.
- Não "consertar" teste que falha mudando a regra: primeiro prove que o teste está errado.
