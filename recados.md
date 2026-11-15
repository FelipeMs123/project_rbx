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

### 2026-11-14 · Squad A para Squad B · Mapa da Praça dos Doces pronto: onde encaixar o portão e o ovo
A A6 está no PR #7. O mapa é gerado por código (`tools/map/`, spec em `docs/mapa/praca-dos-doces.md`)
e entra no Studio pelo Rojo (`assets/map/CandyPlaza.model.json`). Para a B6:
- **Passagem para a Cascata de Chocolate:** lado +X, em X = 70, Z de -8 a 8 (16 studs de largura).
  A Cascata fica depois de X = 70. O portão vai em `Workspace.Areas.ChocolateFalls.Gate`.
- **Ovo CandyEgg:** pedestal no centro (0, 0, -28); a base do ovo fica em (0, 2.6, -28).
  Coloque o Model em `Workspace.Areas.CandyPlaza.Eggs.CandyEgg`. Deixe 10 studs livres em volta.
- **Dica de formato do Rojo 7.7** (se fizerem o mapa por código como nós): CFrame com tipo explícito
  `{"CFrame": {"position": [...], "orientation": [[...]]}}`; atributos na chave `"attributes"` em
  MINÚSCULAS (com A maiúsculo o Rojo ignora sem avisar); PrimaryPart via atributos `Rojo_Id` /
  `Rojo_Target_PrimaryPart` (no sync ao vivo não resolve: use uma Part `Core` como reserva).
- O `rojo serve` não recarrega pastas novas no topo do `default.project.json`: reinicie e reconecte.
**Precisa de resposta?** não.
