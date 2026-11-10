# Kit de teste de expansão

> Use este kit antes de mergear uma **feature de conteúdo** nova (trap, classe, trait, raridade,
> nível, evento, cosmético). O objetivo não é shipar o teste: é provar que o pipeline
> (`docs/pipeline-expansao.md`) funciona no código real e que os gaps aparecem antes do merge.

---

## 1. Regra

- O teste roda em **branch temporária** (`trial/<nome>`) ou worktree; **nunca** direto na `main`.
- A `main` termina limpa; a feature do trial é descartada ou vira patch/relatório.
- O teste mínimo de uma expansão de conteúdo precisa tocar **schema + catálogo + serviço + motor
  (se a mudança aparece em replay) + contratos + docs**, não só o catálogo.
- Se algum passo do pipeline doer, **não contorne**: registre o gap em `docs/gaps.md` e ajuste o
  pipeline antes de seguir.

## 2. Procedimento

```bash
cd ~/jogo-roblox
git switch main
git pull --ff-only
git switch -c trial/<nome>

# 1. implemente o escopo mínimo (ver §3)
# 2. rode o gate e colete as evidências (ver §4)
bash scripts/doctor.sh
bash scripts/check.sh

# 3. salve o patch ANTES de limpar
git add -A
git commit -m "trial: <nome>"
git diff main..HEAD > /tmp/<nome>.patch
git log -1 --oneline

# 4. limpe a branch (a main não recebe o trial)
git switch main
git branch -D trial/<nome>
```

Depois, na `main`:

1. copie o patch para `tools/expansion-test/examples/<nome>.patch` se ele servir de referência;
2. escriba `docs/expansion-test-<data>-<nome>.md` com o [template de relatório](report-template.md);
3. registre os gaps novos/atualizados em `docs/gaps.md`;
4. atualize a linha `GAP:` de `CONTINUAR.md`/`ESTADO.md`;
5. commit só de docs/kit na `main`.

## 3. Escopo mínimo do trial

| Eixo | O que provar |
|---|---|
| schema | `SCHEMA_VERSION++`, campo novo, migração do perfil antigo, fixture e `profile-contract` |
| catálogo | `CONTENT_VERSION++`, definição/validação, defaults, `TRAP_IDS`/variantes pinados |
| serviço | `WallService` valida e persiste o campo; dado inválido falha fechado |
| motor | se o campo muda a batalha: `simVersion++`, hash/acceptance re-ancorados; se não muda, provar que o hash fica igual (default neutro) |
| analytics | evento continua válido; se o campo precisa aparecer no evento, taxonomia v2 |
| docs | spec/economia/ESTADO/MAPA/CONTINUAR atualizados; `check.sh` verde (ele **não** detecta doc velho) |
| replay | `BattleLog`/replay armazenam versão ou valor resolvido; servidor antigo recusa/migra |

## 4. Evidências obrigatórias no relatório

- branch + commit do trial;
- versões: `schema`, `CONTENT_VERSION`, `simVersion`;
- hash base (seed 42) e hash de uma variante (se houver);
- migração de perfil antigo: campos preenchidos e comportamento preservado;
- contagens: invariantes, acceptance, profile, analytics, walls;
- `doctor.sh`/`check.sh` RC e `scan_repo.py --check`;
- gaps descobertos com ID/risco/gatilho;
- veredito: pipeline aguentou? o que precisa fechar antes do merge real?

## 5. Exemplo real

[`examples/class-trait-rarity.patch`](examples/class-trait-rarity.patch) é o patch do primeiro
trial (09/11/2026): schema v2, `class/trait/rarity`, catálogo de variantes, `dmgPct` no motor,
`simVersion 3`, migração v1→v2 e contratos. O relatório está em
[`../../docs/expansion-test-2026-11-10.md`](../../docs/expansion-test-2026-11-10.md).

**Atenção:** o patch é referência, não garantia de apply futuro. Use-o para lembrar dos arquivos e
do escopo, não como `git apply` cego.

## 6. Critério de saída do trial

O trial só “passa” se:

- `check.sh` e `doctor.sh` verdes;
- perfil antigo migra e mantém o comportamento (default neutro);
- dado inválido falha fechado;
- variante muda o resultado de forma determinística (quando aplicável);
- eventos continuam válidos;
- os gaps descobertos estão registrados com gatilho;
- a `main` voltou limpa.
