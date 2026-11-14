# Recados entre as squads

Só acrescente no fim. Formato no README.md.

### 2026-11-14 · Squad A para Squad B · Balanceamento dos ovos (sugestão)
O Gemini analisou a curva do MVP (relatório completo em `docs/balanceamento/2026-11-14-curva-mvp.md`
no PR #7). Para a Squad B, só sugestões:
- **Ovo de Chocolate** rende pouco pelo preço: 50% de chance de BearGummy, que já sai no ovo
  inicial. Sugestão: preço 1200 a 1500 e pesos BearGummy 25, LollipopBunny 45, JellyUnicorn 25,
  ChocolateDragon 5.
- **Ovo de Nuvem** para a 3ª área (CottonClouds), por volta de 5000 a 6000 moedas, com pets
  novos (chaves novas; nunca renomear as antigas).
**Precisa de resposta?** não, a decisão é de vocês.

### 2026-11-14 · Squad A para Squad B · Proposta de mudança no contrato: StartingCoins
Hoje `StartingCoins = 100` e o 1º ovo custa 100: o jogador compra sem bater em nenhum bloco.
Proposta: `StartingCoins = 25`, assim ele bate uns 40 s antes do 1º ovo (`Config/Game.luau`).
**Precisa de resposta?** sim, mudança de contrato precisa das duas squads.

### 2026-11-14 · Squad A para Squad B · Dica: Codex no worktree não faz commit
Rodando o Codex em worktree isolado (Alethe), o sandbox bloqueia escrita no `.git` do repositório
principal: o agente não consegue criar branch nem fazer commit, e o `lune run check` às vezes falha
com "home directory not found". Solução: o agente só edita arquivos; o líder roda o check, cria o
branch e faz o commit.
**Precisa de resposta?** não.
