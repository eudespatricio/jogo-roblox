# CONTINUAR — handoff de sessão

**Data:** 09/11/2026 · **Status:** pré-P0, nenhum código de produção · base `main` @ `82fb9c3`.
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

## Migração para WSL (em andamento)

- Repo publicado: **https://github.com/eudespatricio/jogo-roblox** (branch `main`, commit `0377925`).
- No WSL, clonar em `/home/eudespatricio/jogo-roblox` e rodar `bash scripts/setup-wsl.sh`
  (instala Rokit + ferramentas, roda invariantes e `--check`, imprime o IP).
- **Rede (resolvido em 09/11/2026):** o Rojo roda no WSL escutando **`127.0.0.1:34872`** e o Windows
  alcança **`localhost:34872`** pelo encaminhamento de localhost do WSL. **Não use
  `--address 0.0.0.0`** (quebra o encaminhamento) e **não é necessário firewall**. Regras clássicas
  e do Hyper-V são inócuas em modo NAT (`NATInboundRuleNotApplicable`).
- Teste feito: `rojo serve` no WSL + `http://localhost:34872/api/rojo` → **HTTP 200** no Windows.
- Se um dia precisar de acesso da LAN, aí sim portproxy ou `networkingMode=mirrored`.
- `.tools/` é binário Windows e não é versionado; no WSL as ferramentas vêm do `rokit install`.
- Se a pasta no WSL estiver vazia, o repo ainda não foi clonado — clone antes de ler o resto.

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
| contexto residente | ESTADO 64/80 · MAPA 39/60 · REJEITADOS 16/40 |

---

## Pesquisa de apoio a Q1/Q2 (09/11/2026)

`docs/pesquisa-grade-e-prototipo.md` levanta a evidência para as duas perguntas:

- **Q2:** profundidade não vem do número de células (Kingdom Rush 4–6 torres, Super Auto Pets 5
  slots); 25 células × 5 armadilhas ativas = 53.130 layouts; 25 armadilhas simultâneas seria fora
  da curva. Falta um A/B de 20–30 jogadores (protocolo no doc, §5).
- **Q1:** o protótipo tem 442 linhas, 0% de sobreposição com a Muralha e embute o DataStore caseiro
  já rejeitado; `rojo build` funciona com um stub de 10 linhas (8,6 KB vs 440 B). A evidência
  favorece apagar na P1 com tag + stub + CI.

Nada foi decidido: Q1/Q2 continuam em `docs/auditoria/CONTRADICOES.md`.

---

## Pesquisa de monetização (09/11/2026)

`docs/pesquisa-monetizacao.md` confronta as premissas de receita com o mercado:

- Os TDs do topo examinados vendem **poder e sorte**; cosmético é complemento: torres 168–1.574 R$,
  passe 399–499, cosmético 55–360.
- O modelo usa 4% de pagantes/mês × US$ 5/mês — ARPPU no p95 e pagantes acima da mediana; é cenário
  de topo, não base. O relatório mede 3,8% que pagaram algo **em 12 meses**.
- O gate ARPDAU US$ 0,02 não fecha: o cenário "Negócio" dá 0,0088 líquido (0,0375 bruto). Falta
  definir se o gate é bruto ou líquido.
- Canais melhores: assinatura em moeda local (100% após o 1º mês), Roblox Plus (78–88% + 750 R$ por
  signup), regional pricing automático.
- Preços do GDD seguem em aberto; nada foi decidido.

---

## Revisão de direção (09/11/2026)

`docs/revisao-direcao.md` responde ao pedido original ("a vida depende dessa receita"):

- Engenharia e design: **no caminho certo**. Produto e receita: **não provados**.
- O cenário "Negócio" é TD de porte médio com **monetização de topo** — a combinação mais difícil.
- Com premissas base, BRL 10 mil/mês exige ~39 mil DAU; BRL 50 mil, ~197 mil. Não é plano de lançamento.
- Recomendação: **teste de produto de 3 semanas (US$ 300–500) antes da P0**, com critérios de kill
  definidos (entendimento, diversão, oferta, D1, CTR).
- Não pivotar sem dados; não construir mais motor antes do teste.

---

## Ferramentas (09/11/2026)

`docs/ferramentas.md` audita o que existe e o que falta para qualidade de ponta:

- **Existe:** Studio + Rojo plugin; Rokit (Rojo/StyLua/Selene/Luau); Blender 4.2 no WSL com Cycles
  CUDA (RTX 3060); WSLg; Python 3.14.
- **Instalado em 09/11/2026:** git-lfs 3.8.1, luau-lsp 1.70.1, Lune 0.11.1, Pesde 0.7.4,
  rbxcloud 0.17.0, oxipng 10.2.1, Blender 4.5.15 LTS (`blender4.5`); ffmpeg 7.0.2 já existia.
- **Pronto:** CI (`.github/workflows/ci.yml`) + `scripts/check.sh`; StyLua configurado e `sim`
  formatado; `.gitattributes` LFS + exceção `assets/models`; Krita/Inkscape/Audacity instalados.
- **Falta:** `.luaurc` strict + settings do editor; `pesde.toml` + ProfileStore; Selene bloqueado
  (parser não aceita `+=`); pipeline de asset (calibração/export).
- **Pipeline 3D:** Blender (WSL) → glTF/FBX → Studio 3D Importer → `.rbxm` versionado (LFS) → Rojo;
  calibrar units/axes uma vez (`art/calibration.blend`).
- **Atenção:** `.gitignore` ignora `*.rbxm`; shell não-login não acha `rojo` nem `blender`.
- **Kit mínimo:** ~1 dia para CI+LSP+LFS+Pesde; ~1 dia para 2D/áudio + estrutura `art/`.

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
| `docs/pesquisa-grade-e-prototipo.md` | evidência de Q1 (protótipo) e Q2 (grade vs slots) |
| `docs/pesquisa-monetizacao.md` | preços, benchmarks e canais de receita |
| `docs/revisao-direcao.md` | veredito de rota e teste de 3 semanas pré-P0 |
| `docs/ferramentas.md` | toolchain auditado + pipeline Blender→Studio |
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
