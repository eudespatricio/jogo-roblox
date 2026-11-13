# REJEITADOS — decisões que não voltam sem motivo novo

> Teto: 40 linhas. Toda linha precisa de "reabre se". Sem isso, a ideia está morta.

| Rejeitado | Quando | Por quê | Reabre se |
|---|---|---|---|
| [REABERTO 13/11/2026] Co-op síncrono em dupla | 09/11→13/11/2026 | desbloqueado pelo diretor em 13/11/2026 sob lockstep de comandos por tick + anti-leaver 90s (`docs/campanha-bosses-e-coop-sincrono.md`); P1 S1–S8 segue congelada | re-congela se divergência de replay > 0,1% ou abandono líquido > 25% |
| Energia / timer duro de partidas | 09/11/2026 | corta sessão e afasta 18+; algoritmo pune bounce | economia inflacionar > 30% com cercos livres |
| Loot box / item pago aleatório | 09/11/2026 | política de odds + percepção de P2W | nunca (decisão de princípio) |
| PvP síncrono 1×1 | 09/11/2026 | fila vazia no início e exploit de latência | DAU > 50k e latência regional estável |
| [REABERTO 13/11/2026] Física real híbrida | 09/11→13/11/2026 | desbloqueada pelo diretor em 13/11/2026 em 2 camadas: impulsos inteiros no `Core` + ragdoll/fratura Roblox em `CollisionGroup` isolado (`docs/animacoes-fisica-real-e-vfx.md`) | re-congela no tier Low se FPS p10 mobile < 45 |
| Session lock / DataStore caseiro | 09/11/2026 | ProfileStore cobre crash, Mock e roubo de sessão | ProfileStore abandonado por > 12 meses |
| Grade 7×5 no MVP | 09/11/2026 | legibilidade no celular no drop-in de 5s | público 18+ dominar e mobile < 30% das sessões |
| Avatar visível no MVP | 09/11/2026 | custo de arte + perde DevEx 18+ | identidade social virar o núcleo do jogo |
| Simulação no cliente | 09/11/2026 | exploit trivial; servidor é a verdade | nunca |
| "Gravar 30s para frente" como clipe | 09/11/2026 | a dor do jogador é o passado; replay por seed resolve | CaptureService passar a gravar buffer retroativo |
| 1 armadilha por lane (recorte do PoC) na produção | 09/11/2026 | Q2 exige 5×5 com N=5 e colocação livre; a S2 trocou a matemática (`simVersion 2`) | nunca (S2 fechada; hash `668061367` aposentado) |
| Reembolso ao remover armadilha | 09/11/2026 | taxonomia v1 não tem source de refund; `gold_earned` só aceita raid/defense/daily | taxonomia v2 com source de refund e migração do sink |
| Protótipo de moedas em `src/**` (legado) | 09/11/2026 | 442 linhas, 0% de sobreposição com a Muralha; DataStore caseiro já rejeitado; build de 8,6 KB vs stub de 10 linhas. **Executado na S1:** tag anotada `legacy-coins` em `b07b4c5`, deleção e stub; preservou `src/shared/{sim,data,analytics}` e `src/server/{data,ProfileBoot}` | for usado como harness de Studio/pipeline em 30 dias, ou se o stub de 10 linhas não construir no CI |
