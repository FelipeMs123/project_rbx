# Diário da Squad A

## Painel
| Tarefa | Status | Feito por (ferramenta e modelo) | Branch / PR | Bloqueio ou próximo passo |
|---|---|---|---|---|
| A1 Fórmulas | 🔵 em teste | Codex gpt-6.1-sol / Gemini gemini-4-hydrogen-high | `a/fase1` #7 | Testar no Studio |
| A2 BlockService | 🔵 em teste | Codex gpt-6.1-sol / Codex gpt-6.1-terra | `a/fase1` #7 | Revisar correções do gpt-6.1-terra e testar no Studio |
| A3 AreaService | 🔵 em teste | Codex gpt-6.1-sol / Codex gpt-6.1-terra | `a/fase1` #7 | Revisar correções do gpt-6.1-terra e testar no Studio |
| A4 Cliente dos blocos | 🔵 em teste | Codex gpt-6.1-sol / Codex gpt-6.1-terra | `a/fase1` #7 | Revisar correções do gpt-6.1-terra e testar no Studio |
| A5 HUD e portões | 🔵 em teste | Codex gpt-6.1-sol / Codex gpt-6.1-terra | `a/fase1` #7 | Revisar correções do gpt-6.1-terra e testar no Studio |
| A6 Studio: Praça dos Doces | ⬜ a fazer | não informado | não informado | Felipe montar a área e modelos dos blocos no Studio |

## Registro

### 2026-11-14 · Rodada 2: Gemini (design e revisão)
- **O que foi feito:** Balanceamento da curva de progressão e revisão técnica do PR #7.
- **Como:** Gemini gemini-4-hydrogen-high como rbx-design e rbx-revisor; correções sendo feitas com Codex gpt-6.1-terra.
- **Decisões:** Ajuste nos custos e HPs (CottonClouds 6000, ChocolateFalls 1800, CloudBlock 480 HP, ChocoBlock 150 HP, Gummy e Lollipop ajustados) para evitar 1º rebirth antes da 3ª área e reduzir cliques excessivos no mobile. Meta: 2ª área em 6 a 8 min, 1º rebirth em 25 a 32 min. Relatório em `docs/balanceamento/2026-11-14-curva-mvp.md`. Sugestões de StartingCoins 25 e balanceamento de ovos enviadas para `recados.md`.
- **Problemas e soluções:** Revisão apontou 7 achados (4 médios: colisão de portão invisível bloqueando clique, prompt em peça alta, animação de balanço só na PrimaryPart, sobreposição de HUD e avisos no celular; 3 baixos: aviso de "+0 moedas", dano sem formatação e BillboardGui em pixels fixos). Solução: correções iniciadas com Codex gpt-6.1-terra.
- **Testes:** não informado nesta rodada / Studio: não testado.
- **Próximo passo:** Líder revisar as correções do gpt-6.1-terra, rodar checagens e subir para o PR #7; Felipe testar PR #7 no Studio e iniciar A6.

### 2026-11-14 · Rodada 1: tarefas A1 a A5
- **O que foi feito:** Implementação das fórmulas e BlockService (A1+A2), AreaService (A3), cliente dos blocos (A4), HUD de moedas/gemas, avisos e portões das áreas (A5).
- **Como:** 4 workers do Codex (gpt-6.1-sol via Alethe) em paralelo em worktrees isolados, seguidos de revisão e integração pelo líder (Claude Opus).
- **Decisões:** Unir A1 e A2 no mesmo worker. Criar branch `a/fase1` e PR #7 com um commit por tarefa.
- **Problemas e soluções:** Sandbox do Codex impediu criação de branch e commits no worktree (worker A1+A2 parou e precisou ser relançado só para edição de arquivos); líder assumiu criação de branches, checagens e commits. Na revisão, Claude corrigiu erro de tipo e checagem duplicada na A3, e corrigiu bug na A4 onde clique contínuo no PC falhava por conta da barra superior (`GetMouseLocation` menos `GetGuiInset`).
- **Testes:** `lune run check` (24 testes, TUDO OK, CI verde) / Studio: não testado.
- **Próximo passo:** Revisão de design e código (Rodada 2) e testes no Studio.

### 2026-11-14 · Fase 0: fundação
- **O que foi feito:** Reinício da estrutura do repositório do zero com Rojo, Rokit, Wally e ferramentas auxiliares. Criação de DataService, EconomyService, NetServer/NetClient, stubs, configs, documentação completa e CI.
- **Como:** Desenvolvido pelo Claude Opus (sessão principal) com revisão cruzada pelo Codex (gpt-6.1-sol).
- **Decisões:** Rebalanceamento da divisão do projeto em 6 tarefas para cada squad a pedido do Felipe; economia base passou para a fundação. Mesclado via PR #6 na `main` com squash.
- **Problemas e soluções:** Revisão do Codex apontou 3 problemas (cliente sem retry no GetData, require antes de replicação e RemoteFunction sem handler travando o cliente); todos foram corrigidos pelo Claude antes do merge.
- **Testes:** `lune run check` (TUDO OK, CI configurado) / Studio: não informado.
- **Próximo passo:** Iniciar tarefas da Fase 1 da Squad A (A1 a A5).
