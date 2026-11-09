# REJEITADOS — decisões que não voltam sem motivo novo

> Teto: 40 linhas. Toda linha precisa de "reabre se". Sem isso, a ideia está morta.

| Rejeitado | Quando | Por quê | Reabre se |
|---|---|---|---|
| Co-op em tempo real no MVP | 09/11/2026 | netcode não se paga antes de validar retenção | retenção solo ≥ 15% D1 e dupla assíncrona ≥ 3% D7 |
| Energia / timer duro de partidas | 09/11/2026 | corta sessão e afasta 18+; algoritmo pune bounce | economia inflacionar > 30% com cercos livres |
| Loot box / item pago aleatório | 09/11/2026 | política de odds + percepção de P2W | nunca (decisão de princípio) |
| PvP síncrono 1×1 | 09/11/2026 | fila vazia no início e exploit de latência | DAU > 50k e latência regional estável |
| Física real no gameplay | 09/11/2026 | custo e não determinismo no replay | visual precisar de ragdoll real e houver orçamento |
| Session lock / DataStore caseiro | 09/11/2026 | ProfileStore cobre crash, Mock e roubo de sessão | ProfileStore abandonado por > 12 meses |
| Grade 7×5 no MVP | 09/11/2026 | legibilidade no celular no drop-in de 5s | público 18+ dominar e mobile < 30% das sessões |
| Avatar visível no MVP | 09/11/2026 | custo de arte + perde DevEx 18+ | identidade social virar o núcleo do jogo |
| Simulação no cliente | 09/11/2026 | exploit trivial; servidor é a verdade | nunca |
| "Gravar 30s para frente" como clipe | 09/11/2026 | a dor do jogador é o passado; replay por seed resolve | CaptureService passar a gravar buffer retroativo |
| Protótipo de moedas em `src/**` (legado) | 09/11/2026 | 442 linhas, 0% de sobreposição com a Muralha; DataStore caseiro já rejeitado; build de 8,6 KB vs stub de 440 B. Apagar na P1, preservando `src/shared/sim/` | for usado como harness de Studio/pipeline em 30 dias, ou se o stub de 10 linhas não construir no CI |
