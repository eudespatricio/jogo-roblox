# Teste de sessão no Studio (P0)

> **Atualização (S1, 09/11/2026):** o protótipo de moedas foi apagado (tag `legacy-coins`). O lugar
> agora tem `ProfileBoot` + o stub `Main`; as menções a `Main`/`DataService`/asset legado nas
> evidências abaixo são **históricas** (antes da S1).

> **S3.4 (10/11/2026):** o schema subiu para **v2** (`contentVersion`) e o conteúdo para **v2**
> (`oil → tar`, `catapult`, `simVersion 3`). Os logs da §8 são do schema v1 e ficam como histórico.
> O **Modo B com schema v2 foi executado em 10/11/2026** — `schema=v2 content=v2`, DataStore real,
> sessions 11→12 e `PASSOU (8/8)` (evidência na §9).
>
> **Status:** **Modo A (Mock) e Modo B (DataStore real) aprovados em 09/11/2026 com schema v1** e
> **Modo B schema v2 aprovado em 10/11/2026** (evidência nas §8 e §9).
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

O lugar tem `ProfileBoot` (P0) e o stub `Main` (S1); não há mais o protótipo de moedas.

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

## 4. Modo B — DataStore real (persistência entre servidores)

Pré-requisitos (obrigatórios; sem eles o ProfileStore usa o mock interno dele e **nada é salvo**):

1. **Publicar o lugar:** com o arquivo aberto, *Arquivo → Publicar no Roblox como…* → criar a
   experiência de teste (ex.: `MURALHA P0 — teste`). Um `.rbxl` local tem `PlaceId = 0` e DataStore
   não funciona nele.
2. **Ligar o acesso do Studio:** Creator Hub → *Configurações do jogo → Segurança → Permitir acesso
   do Studio aos Serviços de API* (Game Settings → Security → Enable Studio Access to API Services).
3. No Explorer: `ServerStorage` → `ProfileStoreMock` (boolean) = **`false`**, `ProfileSelfTest` =
   **`true`**. Salve (`Ctrl+S`).

4. **Play (F5).** Esperado no Output:
   - `[ProfileStore]: Roblox API services available - data will be saved`
   - `[perfil] store=MuralhaProfile_v1 modo=DataStore`
   - `[perfil] datastore=Access`
   - `[selftest] PASSOU (8/8)`

5. **Prova entre servidores:** pare e dê **Play de novo** (servidor novo). A chave continua
   `key=User_<id>` e `sessions` continua de onde parou: a linha
   `carregou e migrou · … sessions=3` na segunda execução prova que o `sessions=2` da primeira foi
   gravado no DataStore. `dias_desde_ultimo_acesso=0` e `gold` igual completam a evidência.
   (Cada execução faz **duas** sessões: a do load e a do self-test — por isso o contador sobe de 2
   em 2.)

Se aparecer `[perfil] datastore=NoAccess` (ou `NoInternet`) junto do aviso **MODO B INVÁLIDO**, o
dado **não** foi salvo: falta publicar o lugar ou ligar o acesso do Studio.

### 4.1 Duas contas × dois clientes do Studio

O teste de vários clientes do Studio usa **o mesmo `UserId`** (a sua conta) em todos. As duas sessões
disputam a mesma chave `User_<id>` e a segunda é recusada pelo session lock do ProfileStore
(`StartSessionAsync` → "already loaded in this session"; o jogador leva kick). Isso é o
comportamento correto de **não duplicar**, não um bug — e é a prova de que o lock funciona.

Para ver duas chaves `User_*` distintas de verdade, entre no lugar **publicado** com duas contas
(app/Web), não no Studio. Fica para o playtest; a P0 não depende disso.

## 5. Checklist para colar no handover

| Item | Resultado |
|---|---|
| Modo A: `[selftest] PASSOU (8/8)` | ☑ (09/11/2026, §8) |
| Modo A: nenhuma linha `FALHA` | ☑ (09/11/2026, §8) |
| Modo B: `datastore=Access` e `PASSOU (8/8)` | ☑ (09/11/2026, §8.1) |
| Modo B: `sessions` continuou no novo Play (servidor novo) | ☑ `3` no 2º Play (09/11/2026) |
| Modo B: `gold` preservado no novo Play | ☑ (09/11/2026, §8.1) |
| Modo B: `lastSeenAt` avançou (UTC) | ☑ (09/11/2026, §8.1) |
| Nenhum campo fora do schema no perfil | ☑ (validado em A e B) |

Evidência: copie as linhas `[perfil]`/`[selftest]` do Output para o handover.

## 6. Troubleshooting

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `ProfileStore vendorizado ausente` | `ServerStorage.Vendor` não está no lugar | `bash scripts/check.sh` (o build inclui `vendor/`) |
| `[perfil] StartSessionAsync lancou: ... already loaded in this session` | `EndSession` ainda estava salvando | espere 1s e tente de novo; o controller já tenta 3× com backoff |
| `[perfil] ... schema_future` | perfil gravado por um build mais novo | use o build atual; não sobrescrever dado mais novo |
| `[selftest] FALHA sessions incrementou` | Mock reiniciado entre as sessões | no Modo A o servidor não pode reiniciar no meio do teste |
| `[perfil] datastore=NoAccess` + aviso **MODO B INVÁLIDO** | API Services desligado ou lugar não publicado | publicar o lugar e ligar o acesso do Studio, ou voltar ao Modo A (Mock) |
| Nenhuma linha `[selftest]` | atributo ausente ou fora do Studio | `ProfileSelfTest = true` em `ServerStorage`; self-test só roda em Studio |

## 7. O que **não** entra na P0

- Sink de analytics (`AnalyticsService`) e instrumentação de gameplay: entregues na S7 (sink
  `Null`; persistência da série é GAP-012).
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

Ruído histórico (antes da S1): o protótipo legado (`Main`/`DataService`) falhava sem lugar
publicado e um asset do legado não resolvia (`rbxassetid://203785492`). Ambos saíram com a Q1.

O que fica em aberto: **Modo B** (lugar publicado + API Services, 2 clientes/rejoin) para provar
persistência real entre servidores; o `ProfileStore` avisa que os dados não são salvos no Modo A.

### 8.1 Modo B — DataStore real (09/11/2026 22:12 e 22:14)

Lugar publicado, API Services ligado, `ProfileStoreMock = false`. Duas execuções seguidas (servidores
diferentes), **PASSOU (8/8)** nas duas.

Primeira execução (perfil novo):

```
[perfil] store=MuralhaProfile_v1 modo=DataStore
[ProfileStore]: Roblox API services available - data will be saved
[perfil] datastore=Access
[selftest] PASSOU (8/8)        -- sessions 1 -> 2, lastSeenAt 01:12:26Z -> 01:12:29Z
```

Segunda execução (servidor novo, mesmo perfil):

```
[perfil] carregado key=User_<id> schema=v1 migrado=false dias_desde_ultimo_acesso=0
[perfil] datastore=Access
[selftest] OK   carregou e migrou · schema=v1 gold=0 sessions=3
[selftest] OK   sessions incrementou · 3 -> 4
[selftest] OK   lastSeenAt avancou · 2026-11-10T01:14:43Z -> 2026-11-10T01:14:45Z
[selftest] OK   gold persistiu · 0
[selftest] PASSOU (8/8)
```

`sessions=3` no segundo servidor é a prova de persistência: a primeira execução terminou em 2. O
`ContentId: rbxassetid://203785492` que aparece no meio era asset do protótipo legado (histórico).

Fica para o playtest: duas contas distintas no lugar publicado (duas chaves `User_*`).



---

## 9. Schema v2/contentVersion — S3.4 (executado 10/11/2026)

**Status:** **executado e aprovado**; é a evidência que fecha o **GAP-009** no ProfileStore/DataStore
real. O roteiro abaixo fica para a próxima mudança de schema.

1. `bash scripts/check.sh` verde; `rojo build` e abrir o lugar no Studio (publicar para o Modo B).
2. `ServerStorage.ProfileStoreMock = true` e `ProfileSelfTest = true` (Modo A).
3. Publicar o lugar, ligar API Services e `ProfileStoreMock = false` (Modo B); rodar duas vezes em
   servidores diferentes.
4. Perfil antigo: subir um perfil v1 e confirmar `migrado=true`, `oil → tar` e `contentVersion=2`;
   perfil com `content_future` deve ser recusado com kick e lock devolvido.
5. Copiar as linhas `[perfil]`/`[selftest]` para o handover e atualizar o GAP em `docs/gaps.md`.

**Evidência — Modo B schema v2 (10/11/2026):**

```text
[perfil] store=MuralhaProfile_v1 modo=DataStore
[ProfileStore]: Roblox API services available - data will be saved
[perfil] carregado key=User_... schema=v2 content=v2 migrado=false
[perfil] datastore=Access
[selftest] inicio · modo=DataStore
[selftest] OK   carregou e migrou · schema=v2 content=v2 gold=0 sessions=11 json=nil
[selftest] OK   sem PII e so campos do schema · nil
[selftest] OK   EndSession no leave · activeCount=0
[perfil] carregado key=User_... schema=v2 content=v2 migrado=false
[selftest] OK   recarregou e nao duplicou · activeCount=1
[selftest] OK   sessions incrementou · 11 -> 12
[selftest] OK   lastSeenAt avancou · 2026-11-10T05:55:03Z -> 2026-11-10T05:55:06Z
[selftest] OK   gold persistiu · 0
[selftest] OK   perfil salvo valido · nil
[selftest] PASSOU (8/8)
```

O `migrado=false` é esperado nesta execução porque o perfil já havia sido migrado para v2. Na
primeira carga de um perfil v1, o log mostra `content=v1` na linha de load e depois
`[perfil] conteudo migrado content=v2`. O `ContentId: rbxassetid://203785492` é o asset legado
histórico (ruído, não bloqueia). Os logs também mostram `[build] cena 5x5 pronta` e
`[build] remotes prontos`, confirmando a inicialização do servidor da S4; o QA visual/FPS da S4
continua pendente.
