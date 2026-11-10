# Teste de sessão no Studio (P0)

> **Status:** **Modo A executado e aprovado em 09/11/2026 — 8/8** (evidência na §8).
> O Modo B (DataStore real, persistência entre servidores) segue opcional, para quando
> houver lugar publicado com API Services.
> O que o CI cobre: `sim/profile-contract.luau` (schema, migração, `StartSessionAsync` nil,
> `EndSession`, recarga sem duplicar) e `sim/analytics-contract.luau`.
> O que o CI **não** cobre: `Players`, DataStore, `ProfileStore.Mock` e o lugar de verdade —
> é exatamente isso que este roteiro fecha.

---

## 1. O que este teste prova

| Critério da P0 | Como é verificado |
|---|---|
| carrega | `[perfil] carregado key=User_<id> schema=v1 migrado=...` no Output do servidor |
| salva | `EndSession` no leave e `gold`/`sessions` preservados na recarga |
| não duplica | uma sessão por jogador (`activeCount=1`) e o perfil recarregado é o mesmo |
| sem PII | `ProfileSchema.validate` aceita o perfil (whitelist recusa campo fora do schema) |
| `lastSeenAt` atualizado | carimbo UTC avança entre as duas sessões |

## 2. Preparação

```bash
source scripts/env.sh
bash scripts/check.sh              # gera build/place.rbxl com o codigo da P0
rojo serve default.project.json    # opcional: WSL em 127.0.0.1:34872
```

No Studio, escolha um caminho:

- abrir `build/place.rbxl` (build do `check.sh`), ou
- conectar o plugin Rojo no projeto (`localhost:34872`).

O lugar tem dois scripts de servidor: `Main` (protótipo de moedas, **legado**) e `ProfileBoot`
(P0). Avisos do legado sobre DataStore podem aparecer; eles não afetam o teste e morrem na P1.

## 3. Modo A — Mock (rápido, sem publicar; é o padrão no Studio)

1. No Explorer: `ServerStorage` → Attributes → adicione `ProfileSelfTest` (boolean) = `true`.
2. (Opcional) `ProfileStoreMock` (boolean) = `true` — o padrão no Studio já é Mock.
3. **Play** (F5). O self-test roda sozinho no primeiro jogador.
4. Confira o Output do servidor:

```
[perfil] store=MuralhaProfile_v1 modo=Mock
[perfil] carregado key=User_<id> schema=v1 migrado=false dias_desde_ultimo_acesso=nil
[selftest] inicio · modo=Mock
[selftest] OK   carregou e migrou · schema=v1 gold=0 sessions=1 json=nil
[selftest] OK   sem PII e so campos do schema · nil
[selftest] OK   EndSession no leave · activeCount=0
[selftest] OK   recarregou e nao duplicou · activeCount=1
[selftest] OK   sessions incrementou · 1 -> 2
[selftest] OK   lastSeenAt avancou · 2026-11-09T...Z -> 2026-11-09T...Z
[selftest] OK   gold persistiu · 0
[selftest] OK   perfil salvo valido · nil
[selftest] PASSOU (8/8)
```

**Aceite:** todas as linhas `OK` e uma linha `PASSOU (8/8)`. Qualquer `FALHA` reprova.

> Mock guarda o perfil na memória do servidor: fechar o Play e abrir de novo **reinicia** os
> dados. Persistência entre servidores é o Modo B.

## 4. Modo B — DataStore real (persistência e dois clientes)

Pré-requisitos: lugar **publicado** (place de teste) e *Game Settings → Security → Enable Studio
Access to API Services* ligado. Sem isso o ProfileStore cai em `NoAccess` e o Mock é o caminho.

1. `ServerStorage` → `ProfileStoreMock` (boolean) = `false`.
2. `ProfileSelfTest` = `true` (roda o ciclo salvar/recarregar no DataStore real).
3. **Test → Players → 2 players** (Start Server + 2 Players).
4. No Output do servidor, esperado:
   - dois `[perfil] carregado key=User_<idA>` e `key=User_<idB>` (chaves distintas, um perfil por
     jogador);
   - `[selftest] PASSOU (8/8)` para o primeiro jogador;
   - nenhum `[perfil] ... falhou`.
5. **Rejoin entre servidores:** com um cliente, saia e entre de novo (o teste recria o servidor).
   Esperado no Output: mesmo `key=User_<id>`, `sessions` continuando de onde parou (não volta para
   1), `gold` preservado e `dias_desde_ultimo_acesso` = 0 ou 1.

**Aceite:** duas chaves distintas; `sessions` incrementa em vez de reiniciar; `gold` preservado;
nenhum perfil duplicado; `lastSeenAt` no futuro nenhum (carimbo do servidor).

## 5. Checklist para colar no handover

| Item | Resultado |
|---|---|
| Modo A: `[selftest] PASSOU (8/8)` | ☑ (09/11/2026, §8) |
| Modo A: nenhuma linha `FALHA` | ☑ (09/11/2026, §8) |
| Modo B: duas chaves `User_*` distintas | ☐ |
| Modo B: `sessions` continuou no rejoin | ☐ |
| Modo B: `gold` preservado no rejoin | ☐ |
| Modo B: `lastSeenAt` avançou (UTC) | ☐ |
| Nenhum campo fora do schema no perfil | ☐ |

Evidência: copie as linhas `[perfil]`/`[selftest]` do Output para o handover.

## 6. Troubleshooting

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `ProfileStore vendorizado ausente` | `ServerStorage.Vendor` não está no lugar | `bash scripts/check.sh` (o build inclui `vendor/`) |
| `[perfil] StartSessionAsync lancou: ... already loaded in this session` | `EndSession` ainda estava salvando | espere 1s e tente de novo; o controller já tenta 3× com backoff |
| `[perfil] ... schema_future` | perfil gravado por um build mais novo | use o build atual; não sobrescrever dado mais novo |
| `[selftest] FALHA sessions incrementou` | Mock reiniciado entre as sessões | no Modo A o servidor não pode reiniciar no meio do teste |
| `NoAccess` no DataStore | API Services desligado ou lugar não publicado | Modo A (Mock) ou publicar o lugar |
| Nenhuma linha `[selftest]` | atributo ausente ou fora do Studio | `ProfileSelfTest = true` em `ServerStorage`; self-test só roda em Studio |
| `Main`/`DataService` lançam erro no Play | protótipo legado de moedas sem lugar publicado (`You must publish this place…`) | esperado no Modo A; morre com o legado na P1 |

## 7. O que **não** entra na P0

- Sink de analytics (`AnalyticsService`) e instrumentação de gameplay: P1.
- Roubo de sessão entre dois servidores simultâneos (dois dispositivos, mesma conta): coberto pelo
  session lock do ProfileStore; teste manual de dois dispositivos fica para o playtest.
- UI, cena 5×5, loja: P1.

## 8. Execução registrada — Modo A, 09/11/2026 21:49 (America/Sao_Paulo)

Lugar: `build/place.rbxl` (cópia em `C:\Users\Eudes\Desktop\muralha-p0-place.rbxl`),
`ProfileSelfTest = true` em `ServerStorage`, Play Solo. Resultado: **PASSOU (8/8)**.

```
[ProfileStore]: Roblox API services unavailable - data will not be saved   -- esperado no Studio
[perfil] store=MuralhaProfile_v1 modo=Mock
[perfil] carregado key=User_<id> schema=v1 migrado=false dias_desde_ultimo_acesso=nil
[selftest] OK   carregou e migrou · schema=v1 gold=0 sessions=1 json=nil
[selftest] OK   sem PII e so campos do schema · nil
[perfil] sessao encerrada key=User_<id>
[selftest] OK   EndSession no leave · activeCount=0
[perfil] carregado key=User_<id> schema=v1 migrado=false dias_desde_ultimo_acesso=0
[selftest] OK   recarregou e nao duplicou · activeCount=1
[selftest] OK   sessions incrementou · 1 -> 2
[selftest] OK   lastSeenAt avancou · 2026-11-10T00:49:02Z -> 2026-11-10T00:49:04Z
[selftest] OK   gold persistiu · 0
[selftest] OK   perfil salvo valido · nil
[selftest] PASSOU (8/8)
```

Ruído esperado, não é P0: o protótipo legado (`Main`/`DataService`) falha sem lugar publicado
(`You must publish this place to the web to access DataStore`) e um asset do legado não resolve
(`rbxassetid://203785492`). Os dois saem com o legado na P1 (Q1).

O que fica em aberto: **Modo B** (lugar publicado + API Services, 2 clientes/rejoin) para provar
persistência real entre servidores; o `ProfileStore` avisa que os dados não são salvos no Modo A.

