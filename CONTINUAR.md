# CONTINUAR — handoff de sessão

**Data:** 09/11/2026 · **Status:** pré-P0, nenhum código de produção · base `master` @ `f28436c`.
Este arquivo é autossuficiente: a conversa pode ser fechada.

---

## O que é este projeto

**MURALHA** — tower defense invertido + autobattler assíncrono para Roblox, mobile-first, sem avatar
visível (habilita DevEx 18+ e corta custo de arte). O jogador monta a muralha, outros atacam
enquanto ele está offline, e um replay determinístico de 8s mostra o que aconteceu — com botão de
gravar clipe via `CaptureService`.

Equipe: 1 humano (direção, cena, game feel, QA) + 2 agentes (motor/CI e sistemas/economia).
A divisão de tarefas **não foi executada**; a P0 **não foi autorizada**.

---

## Onde paramos

- Conceito aprovado (GDD v1.1, decisões 1–5 fechadas).
- Motor determinístico v2 provado em `sim/` (inteiro, 1.200 ticks, `mul32`/`add32`).
- Tooling fechado: Rokit, GitHub Actions, ProfileStore.
- Auditoria `context-recovery` concluída: 7 contradições resolvidas, **2 abertas (Q1/Q2)**.
- Contexto residente instalado e dentro do teto.
- **Nada de P0/P1 iniciado por decisão do diretor.**

---

## Fatos (não reinventar)

| Métrica | Valor |
|---|---|
| tick / cap | 0,05 s · 1.200 ticks (60 s) |
| estado | 100% inteiro (`MILLI = 1000`) |
| custo por batalha | 1,28 ms (~780/s) |
| determinismo | hash `668061367` (seed 42, 3 execuções) |
| 500 seeds | 500 hashes distintos · 64,8% vitória do defensor |
| invariantes | **10/10** (`sim/invariants.luau`) |
| contexto residente | ESTADO 60/80 · MAPA 35/60 · REJEITADOS 16/40 |

---

## A decisão que a próxima sessão precisa fechar

### Q1 — protótipo de moedas em `src/**`

| Opção | Efeito |
|---|---|
| **(a) apagar na P1** (recomendado) | remove ambiguidade; histórico fica no git |
| (b) manter como cena de teste | preserva pipeline Rojo, mas confunde "o que é o jogo" |

### Q2 — grade de produção

| Opção | Efeito |
|---|---|
| **(a) 5×5 com 25 células**, armadilhas por célula, 5 lanes de caminhada (recomendado) | profundidade real; exige o motor de produção |
| (b) 5 slots (1 por lane), como no PoC | mais simples, porém raso e igual a todo TD do Roblox |

**Depois de responder:** apagar `docs/auditoria/CONTRADICOES.md` e registrar a decisão no GDD
(design) ou em `.context/REJEITADOS.md` (descarte).

**Próximo passo sugerido (antes da P0):** fechar a taxonomia de analytics — o motor precisa emitir
os eventos, e mudar depois custa retrabalho.

---

## O que está documentado

| Arquivo | O que é |
|---|---|
| `docs/gdd-muralha.md` | GDD v1.1: loop, drop-in, modos, economia, fases, decisões |
| `docs/spec-motor-deterministico.md` | motor, replay, clipe/CaptureService, anti-cheat, auditorias |
| `docs/padroes-engenharia.md` | regras com fonte oficial + tooling + CI |
| `docs/pesquisa-tendencias-2026.md` | mercado, gêneros, algoritmo |
| `docs/pesquisa-jogadores.md` | reclamações/pedidos + 10 regras |
| `docs/tese-produto-e-economia.md` + `docs/modelo-financeiro.xlsx` | economia unitária |
| `docs/referencias-tower-defense.md` | jogos/vídeos para estudar |
| `docs/auditoria/CONTRADICOES.md` | **temporário**: 7 resolvidas + Q1/Q2 |
| `sim/core.luau` · `sim/poc.luau` · `sim/invariants.luau` | motor, benchmark, oráculo |
| `.context/ESTADO|MAPA|REJEITADOS.md` | contexto residente com teto |
| `skills/context-recovery/` | protocolo de auditoria + scanner + templates |

---

## Regras invioláveis

1. **Não iniciar P0/P1 sem autorização explícita do diretor.**
2. `src/**` é legado; não é base do jogo novo.
3. Depois de editar `sim/core.luau`, rodar `sim/invariants.luau`.
4. Mudou a matemática → subir `simVersion` e registrar na spec.
5. `bit32` só recebe `[0, 2^32)`: usar `add32`/`mul32`.
6. Contexto residente tem teto (80/60/40); `--check` falha se estourar.
7. Invariante não vira markdown: vira teste ou vira pergunta.
8. Não reabrir `REJEITADOS.md` sem a condição objetiva listada.

---

## Achados que não podem se perder

1. **`bit32.band` com double > 2^32 retorna lixo** (`band(7,2e16) = 1473511424`), não módulo.
2. **Aftman está arquivado** (último push 2025-07-09); Rokit é o sucessor ativo.
3. **ProfileStore** cobre crash de servidor, `Mock` e roubo de sessão — não escrever o nosso.
4. **A Video Captures API só grava para frente** (30s); o pedido do jogador é o passado — nosso
   replay por seed é a vantagem competitiva.
5. **O `mul32` antigo não errava resultado neste build**; era violação de faixa (risco de
   portabilidade). Corrigido como endurecimento, não como bugfix.
6. **O invariante I6 falhou primeiro porque o teste estava errado** (muralha morria antes do cap),
   não o código. Consertamos o teste.
7. **O README descrevia o jogo de moedas** — doc mais velho que código mente; a radiografia pegou.

---

## Como retomar

Cole na nova sessão:

> Você está no repositório `jogo-roblox` (projeto MURALHA, pré-P0). Leia `AGENTS.md`,
> `.context/ESTADO.md`, `.context/MAPA.md` e `CONTINUAR.md`. Rode os comandos de verificação da
> seção 7 do CONTINUAR (invariants, poc, --check). Não inicie P0. Comece fechando Q1 (src legado)
> e Q2 (grade 5×5 com 25 células vs 5 slots), depois proponha a taxonomia de analytics.
