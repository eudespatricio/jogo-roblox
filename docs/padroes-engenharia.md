# Padrões de engenharia — com fonte, não com opinião

Regra deste documento: **só entra o que tem fonte primária**. Ferramenta de comunidade entra marcada
como "prática de mercado" e nunca como "verdade da Roblox".

## Hierarquia de autoridade

| Nível | Fonte | Exemplo |
|---|---|---|
| **A1** | documentação oficial da Roblox | [Security tactics](https://create.roblox.com/docs/scripting/security/security-tactics), [DataStore best practices](https://create.roblox.com/docs/cloud-services/data-stores/best-practices) |
| **A2** | documentação oficial da linguagem | [Luau performance](https://luau.org/performance/), [Roblox Lua Style Guide](https://roblox.github.io/lua-style-guide/) |
| **B** | prática consolidada, sem doc oficial | Rojo, StyLua, Selene, TestEZ |
| **C** | opinião de criador | não usado neste projeto |

---

## 1. Segurança: o que a Roblox manda fazer

Da página oficial de [táticas de segurança](https://create.roblox.com/docs/scripting/security/security-tactics):

> "Nunca confie no cliente... assuma que cada dado enviado pelo cliente foi manipulado, fabricado
> ou enviado com intenção maliciosa."
> "O servidor deve ser a fonte final de verdade para todos os estados de simulação, regras,
> progressão e decisões críticas."
> "Partition responsibilities early. Keep logic and data in ServerScriptService from day one.
> Never place them in replicated containers like ReplicatedStorage or Workspace."

A doc também define o *threat model* obrigatório por feature. Vou aplicá-lo como checklist de PR:

1. Se o cliente tem controle total, como isso é explorado?
2. Se qualquer parâmetro puder ser qualquer valor, qual o pior resultado?
3. E se for chamado 1.000×/s? Qual o limite correto?
4. Dá para arruinar a experiência de outro jogador com isso?
5. Qual o custo máximo de recurso dessa feature?
6. Qual o mínimo de estado interno que preciso expor?

**Aplicação na Muralha:** o cliente só envia intenções (`PlaceTrap`, `StartRaid`, `ClaimReward`);
a simulação roda no servidor; recompensa é idempotente por `battleId`. O cliente pode re-simular
para renderizar, nunca para decidir.

---

## 2. Estrutura de projeto

### 2.1 Árvore (Rojo)

```
src/
  shared/          -> ReplicatedStorage.Shared  (Config, tipos, sim pura)
    sim/           motor determinístico, sem API do Roblox
  server/          -> ServerScriptService        (sistemas autoritativos)
  client/          -> StarterPlayerScripts       (render, input, UI)
  world/           -> Workspace                  (mapa, spawn)
```

Regras de dependência (justificadas pela seção 1):

| Regra | Motivo |
|---|---|
| `shared` não conhece `server` nem `client` | o motor precisa rodar no Luau CLI nos testes |
| `client` pode ler `shared`, nunca `server` | lógica de servidor não é replicada |
| `server` pode ler `shared`, nunca `client` | direção única de dependência |
| `sim/` não usa `Instance`, `workspace`, `RunService` | determinismo e teste headless |

### 2.2 Convenções de arquivo (Style Guide oficial da Roblox)

Ordem obrigatória dentro do arquivo ([fonte](https://roblox.github.io/lua-style-guide/)):

1. comentário de bloco explicando por que o arquivo existe;
2. serviços via `game:GetService` no topo;
3. `require` no topo, ordenados alfabeticamente;
4. constantes de módulo;
5. variáveis e funções;
6. o objeto retornado;
7. `return`.

Outras regras oficiais que vamos seguir à risca:

- nome do arquivo = nome do objeto exportado;
- `PascalCase` para classes/enums, `camelCase` para locais e membros, `LOUD_SNAKE_CASE` para constantes;
- indentação com tabs, 100 colunas de código, 80 de comentário;
- `if-then-else` no lugar de `x and y or z`;
- classes por protótipo com `__index` apontando para a própria tabela (otimiza o type checker e a VM);
- erro: retornar `success, result` em vez de lançar exceção, exceto validação de uso.

### 2.3 Organização por feature, não por tipo

`server/raids/`, `server/walls/`, `server/economy/` — cada pasta com `Service.luau`, `Types.luau`,
`Config.luau`. Evita o "god script" que o próprio Style Guide desaconselha ao falar de arquivos
que precisam de comentários de seção: *"comments that only exist to break up a large file are a code
smell"*.

---

## 3. Modelagem de dados (DataStore)

Fonte: [Best practices for data stores](https://create.roblox.com/docs/cloud-services/data-stores/best-practices).

| Regra oficial | Como aplicamos |
|---|---|
| "Use a small, fixed set of data stores" | 1 store `PlayerData`, 1 store `BattleLog` |
| "one key per player... 4 MB limit" | `User_{UserId}` com perfil inteiro; battle log separado |
| "static key patterns" | `User_123`, `Battle_{battleId}` — nunca display name |
| "buffer player data in memory" | perfil carregado no join, salvo a cada 180s e em checkpoints |
| "prefer UpdateAsync over SetAsync" | toda escrita de perfil usa `UpdateAsync` |
| "retry transient failures... exponential backoff com jitter" | retry 3×, 0,5s → 1s → 2s + jitter |
| "process retries in order per key" | fila por jogador; nunca duas escritas concorrentes |
| "stagger recurring requests" | autosave com offset aleatório por servidor |

**Sessão e duplicação:** session locking (ProfileStore) é a prática de mercado para impedir que dois
servidores escrevam o mesmo perfil. Sem isso, o jogador que troca de servidor pode perder progresso —
exatamente o tipo de bug que gera review negativo.

**Schema versionado:**

```lua
type Profile = {
    schemaVersion: number,   -- migração obrigatória ao subir
    wall: { gridWidth: number, activeTrapLimit: number, cells: { [number]: Cell } },
    gold: number,
    league: { points: number, season: number },
    cosmetics: { [string]: boolean },
    stats: { raids: number, defenses: number, lastSeenAt: number },
}
```

No MVP, `activeTrapLimit = 5` e `gridWidth = 5`; a expansão para 7 é dado, não código (Q2,
09/11/2026).

Regras: migração testada com fixture de versão antiga; nenhum campo é removido sem migração;
`lastSeenAt` é a base do D1/D7; nada de PII.

---

## 4. Performance (com fonte)

Da doc oficial de [performance](https://create.roblox.com/docs/performance-optimization/improve):

- eventos de `RunService` são caros e rodam todo frame — usar só quando essencial;
- tarefas grandes devem ser quebradas com `task.wait()` ou multithreading;
- scripts de servidor podem usar **native code generation**;
- vazamentos clássicos: conexões não desconectadas e tabelas de jogador que crescem para sempre;
- o objeto `Player` **não é destruído** quando o jogador sai — conexões nele continuam vivas;
- MicroProfiler + `debug.profilebegin/end` para medir, não adivinhar.

Da doc oficial do [Luau](https://luau.org/performance/):

- acesso a campo é rápido quando o **shape da tabela é uniforme** e o nome é conhecido em compilação;
- `__index` deve apontar para tabela, nunca para função;
- `table.create` para arrays de tamanho conhecido; `table.insert` para append;
- iteração generalizada (`for k, v in t`) é tão rápida quanto `pairs`/`ipairs` e evita chamada;
- evitar alocação em loop apertado (GC assist);
- `getfenv`/`setfenv`/`loadstring` desoptimizam o ambiente inteiro.

**Nosso caso:** a simulação já é inteira, sem Instances, 20 Hz, 1,38 ms por batalha. O gargalo é
renderização no cliente — por isso pool de modelos, câmera fixa e LOD.

---

## 5. Qualidade de código

| Prática | Fonte | Aplicação |
|---|---|---|
| `--!strict` em todo módulo novo | tipos do Luau | CI quebra se o analyzer reclamar |
| `luau-analyze` no CI | CLI oficial | roda em `src/shared` sem depender do Studio |
| StyLua | prática de mercado (B) | formatação determinística, sem discussão |
| Selene | prática de mercado (B) | lint de estilo e bugs comuns |
| testes headless | Luau CLI | `sim/poc.luau` já roda fora do Roblox |
| `simVersion` no save | nossa regra | replay velho não paga recompensa |

---

## 6. Anti-patterns (com o porquê)

| Anti-pattern | Por que quebra | Fonte |
|---|---|---|
| Lógica de jogo no cliente | exploit trivial | security tactics |
| Dados do jogador em `ReplicatedStorage` | vazamento e manipulação | security tactics |
| `SetAsync` para progressão | sobrescreve escrita concorrente | DataStore best practices |
| `DataStore` por jogador | estoura limites e dificulta migração | DataStore best practices |
| `RunService.Heartbeat` para tudo | custo por frame desnecessário | performance |
| Conexão em `Player` sem `Disconnect` | vaza memória por sessão | performance |
| Tabela de jogadores sem limpeza | cresce para sempre | performance |
| Física real no gameplay | custo e não determinismo | nosso motor |
| `getfenv`/`loadstring` | desoptimiza o ambiente | Luau performance |
| Arquivo com "comentário de seção" | sinal de arquivo grande demais | style guide |

---

## 7. Regra → fonte → aplicação → teste

| Regra | Fonte | Aplicação | Teste que prova |
|---|---|---|---|
| servidor é a verdade | A1 | sim no servidor, cliente só renderiza | hash do replay bate |
| lógica fora de ReplicatedStorage | A1 | `src/server` | revisão de árvore no CI |
| 1 key por jogador | A1 | `User_{id}` | schema test com fixture |
| escrita com `UpdateAsync` | A1 | perfil | teste de concorrência |
| retry com backoff+jitter | A1 | DataStore wrapper | teste com falha simulada |
| sem float no tick | A2 | motor inteiro | `CheckIntegers()` |
| shape de tabela uniforme | A2 | tipos fixos no motor | benchmark no CI |
| conexões desconectadas | A1 | serviços | teste de join/leave 100× |
| sem vazamento de jogador | A1 | tabela limpa no `PlayerRemoving` | memória estável em soak test |
| estilo consistente | A2 | StyLua + regras do guia | CI de formatação |

---

## 8. Decisões de tooling — fechadas em 09/11/2026

| Decisão | Escolha | Evidência verificada |
|---|---|---|
| Gerenciador de binários | **Rokit** | repositório do Aftman está **arquivado** (`archived=true`, último push 2025-07-09); Rokit ativo (push 2026-09-27, release v1.2.0) e com compatibilidade drop-in com `aftman.toml`/`foreman.toml` |
| CI | **GitHub Actions** | doc oficial: runners padrão em repositório **público são gratuitos** e não consomem a cota; em privado consomem a cota mensal do plano |
| Session locking | **ProfileStore vendorizado + wrapper nosso** | ProfileStore é um ModuleScript único com session lock, `Mock` para teste, `Reconcile` para template e `VersionQuery` para rollback; a doc avisa que servidor pode crashar antes do save final e que `StartSessionAsync` pode retornar `nil` |

### 8.1 Por que não escrever o session lock sozinho

A documentação do ProfileStore cobre exatamente os casos que um `UpdateAsync` caseiro erra:

- **hard crash sem `BindToClose`** → a sessão fica presa; o ProfileStore negocia a troca de dono
  entre servidores em vez de esperar expirar;
- **`StartSessionAsync` pode retornar `nil`** quando outro servidor pega a sessão no mesmo instante —
  é preciso tratar (kick + rejoin) e não assumir que sempre funciona;
- **`OnLastSave` pode nunca disparar** em crash de servidor (a própria doc avisa) — logo, nada de
  lógica crítica dependendo desse evento;
- **`EndSession()` é obrigatório**, senão o servidor acumula requests;
- **`Profile.Mock`** permite testar o fluxo inteiro sem tocar em chave de produção.

Wrapper nosso por cima: valida `schemaVersion`, migra, e só expõe `Profile.Data` tipado.

### 8.2 Pipeline de CI (15–20s por push)

```yaml
name: ci
on: [push, pull_request]
jobs:
  luau:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: CompeyDev/setup-rokit@v0.1.2
      - run: stylua --check src sim
      - run: selene src sim
      - run: luau-analyze src/shared/sim
      - run: luau sim/poc.luau
```

Observação honesta: `luau-analyze` roda limpo só no que **não** depende da API do Roblox
(`src/shared/sim`). Módulos com `game:GetService` precisam do dump de tipos da Roblox e são
analisados no Studio — não fingir que o CI cobre tudo.

Versões fixadas em `rokit.toml`: Rojo 7.7.1, StyLua 2.6.0, Selene 0.32.0, Luau 0.746 (todas
conferidas nas releases oficiais em 09/11/2026).

### 8.3 Ainda abertas

1. **Analytics:** taxonomia v1 em `docs/taxonomia-analytics.md`; implementação do sink e do validador na P0.
2. **Feature flags:** necessárias para testar variantes de drop-in sem republicar — provavelmente
   um `Config` remoto via `DataStore` + cache local.
