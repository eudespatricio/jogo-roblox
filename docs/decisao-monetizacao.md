# Decisão — premissas de monetização e gate ARPDAU

> **Decidida em 09/11/2026.** Base de planejamento **2% de pagantes/mês (MAU) × ARPPU US$ 2**;
> topo **4,5% × US$ 5**; gate **ARPDAU líquido ≥ US$ 0,005** (bruto ≈ US$ 0,0225).
> Fontes: [pesquisa de monetização](pesquisa-monetizacao.md), [tese](tese-produto-e-economia.md),
> [modelo financeiro](modelo-financeiro.xlsx), [revisão de direção](revisao-direcao.md) §5.

---

## 1. O problema tinha três camadas

| Camada | O que estava errado | Status |
|---|---|---|
| **Modelo** | 64 das 88 células de fórmula estavam com referências deslocadas; os valores cacheados escondiam o erro e um recálculo quebraria a planilha | **corrigido** (§5) |
| **Premissas** | 4% de pagantes/mês e ARPPU US$ 5 são combinação de topo: 3,8% é taxa de **12 meses**, e US$ 5 é o **p95**; o modelo tratava os dois como base | **decidido**: base 2% × US$ 2 |
| **Gate** | “ARPDAU ≥ US$ 0,02” não dizia se era bruto ou líquido; o “Negócio” dava 0,0375 bruto e 0,0088 líquido | **decidido**: líquido ≥ 0,005 |

---

## 2. O modelo, com as premissas decididas

Base: **25 mil DAU / 125 mil MAU**, câmbio 5,4, repasse líquido de **22,176%** (10% do gasto
elegível ao 18+). Valores mensais.

| Cenário | Pagantes | ARPPU | Bruto | Líquido | BRL | ARPDAU bruto | ARPDAU líquido | DAU p/ BRL 10 mil |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Piso | 1% | US$ 1 | 1.250 | 277 | 1.497 | 0,0017 | 0,00037 | 167.014 |
| **Base** | **2%** | **US$ 2** | **5.000** | **1.109** | **5.988** | **0,0067** | **0,00148** | **41.754** |
| Base com ARPPU de topo | 2% | US$ 5 | 12.500 | 2.772 | 14.969 | 0,0167 | 0,00370 | 16.701 |
| **Topo** | **4,5%** | **US$ 5** | **28.125** | **6.237** | **33.680** | **0,0375** | **0,00832** | **7.423** |

Com 25% de gasto elegível (23,52% líquido), o topo sobe para BRL 35.721; a tabela usa 10% para
não herdar a hipótese otimista.

---

## 3. O que os números dizem

1. **3,8% não é taxa mensal.** A GameAnalytics mede “pagou algo no período” (12 meses). A base de
   planejamento é **2% mensais**; 4% é topo.
2. **US$ 5 não é ARPPU base.** Mediana US$ 0,70; p75 US$ 1,25; p90 US$ 2,33; p95 US$ 4,80.
   **US$ 2 é base alta**; US$ 5 é teto.
3. **Base a 25 mil DAU dá ~BRL 6 mil/mês.** Para BRL 10 mil/mês com base, precisa de **~42 mil DAU**;
   com topo, **~7,4 mil DAU**.
4. **O gate antigo de US$ 0,02 bruto ≈ US$ 0,0044 líquido** — quase exatamente o novo gate de
   US$ 0,005 líquido (≈ BRL 20,2 mil/mês a 25 mil DAU; bruto ≈ 0,0225).
5. **O “Negócio” é cenário de topo, não meta base.** A tese agora o rotula assim.

---

## 4. A decisão

| Item | Decisão |
|---|---|
| Premissas de planejamento | **2% pagantes/mês (MAU) × ARPPU US$ 2 × 10% do gasto 18+ elegível** |
| Cenário de topo | **4,5% × US$ 5 × 25% elegível** (23,52% líquido) |
| Piso | **1% × US$ 1** |
| Gate | **ARPDAU líquido ≥ US$ 0,005**; reportar bruto e líquido sempre |

Consequência, sem maquiagem: a base (0,00148) **falha por 3,4×**; 2% com ARPPU US$ 5 (0,00370)
também falha; **só o cenário de topo (0,00832) passa**. O gate preserva a intenção do antigo
US$ 0,02 bruto e torna explícito o que a revisão já dizia: o plano exige monetização de hit.

**Alternativa registrada (não escolhida):** ARPDAU líquido ≥ US$ 0,0025 (≈ BRL 10,1 mil/mês a
25 mil DAU; bruto ≈ 0,0113), que o cenário 2% × US$ 5 passaria.

---

## 5. O bug do modelo (corrigido)

- **64 de 88** células de fórmula tinham referências deslocadas. Exemplos: `Premissas!B25` era
  `=B15/B14` (deveria ser `=B14/B13`); `Cenarios!E6` dividia por DAU e omitia `% pagantes`;
  `Metas!C6` usava a coluna errada.
- Os **valores cacheados** estavam certos (foram calculados com as fórmulas boas), então a planilha
  *parecia* correta. Ao recalcular, `Cenarios!F6` cairia de 35.721 para ~1,59.
- Correção feita **no XML**, trocando só o texto das fórmulas: estilos, larguras e valores cacheados
  preservados. Recálculo com LibreOffice das 88 células: **0 divergências**.
- Depois, as premissas base foram aplicadas (B8 = 10%, B11 = 2, B12 = 2%, B14 = 25.000) e os caches
  das 88 fórmulas foram recalculados e reinjetados: **0 divergências e 0 diferenças de estilo**.
- Lição de processo: valor cacheado não é teste. O gate de qualidade precisa recalcular a planilha
  (ou comparar fórmula × cache) antes de usar número em decisão.

---

## 6. O que foi aplicado

- `docs/modelo-financeiro.xlsx`: premissas base, textos e caches recalculados.
- [GDD](gdd-muralha.md) §8: gate ARPDAU líquido ≥ US$ 0,005, com bruto e BRL de referência.
- [Tese](tese-produto-e-economia.md) §3: base 2% × US$ 2, tabela de metas e cenários; “Negócio”
  passa a “topo”.
- [Pesquisa de monetização](pesquisa-monetizacao.md): nota de decisão e §7 atualizada.
- `ProfileStore`: vendorizado em `vendor/ProfileStore.luau` (Apache-2.0, commit `45c9847`), fora do
  `src/**` legado; wrapper e schema v1 continuam P0.

**O que não mudou:** preços do GDD, proibições de loot box/venda de poder, orçamento do teste de
3 semanas e a decisão de não iniciar P0/P1 sem autorização.
