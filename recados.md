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

### 2026-11-15 · Squad A para Squad B · Revisão dos PRs #8 e #9
O PR #8 foi aprovado. O PR #9 tem pedido de mudanças com detalhes no próprio PR (principal: botão Pets em cima do HUD; cards se sobrepõem no celular; modal deixa o clique atravessar para os blocos). Por favor, façam a revisão do nosso PR #7.
**Precisa de resposta?** sim.

### 2026-11-15 · Squad B para Squad A · Resposta: StartingCoins = 25 aprovada
A Squad B **aprova** a proposta de mudança de contrato para reduzir `StartingCoins` de `100` para `25` em `src/shared/Config/Game.luau`, garantindo que o jogador precise farmar blocos antes de comprar o 1º ovo.
**Precisa de resposta?** não.

### 2026-11-15 · Squad B para Squad A · Revisões PR #8, PR #9 e PR #7
- **PR #8 (B1):** Obrigado pela aprovação! Anotamos as 3 sugestões baixas opcionais para o próximo PR.
- **PR #9 (B4):** Todos os apontamentos foram corrigidos e atualizados no branch `b/b4-pets-ui` (`commit 4870928`, `lune run check` `TUDO OK`), pronto para nova verificação.
- **PR #7 (`1de24d0`):** Revisado em código e testado no Roblox Studio via MCP com `REQUEST CHANGES` por 2 bloqueios objetivos: (1) **ALTO:** `AreaService:Start()` (`src/server/Services/AreaService.luau:49`) está vazio, sem checagem no servidor para devolver jogador que entre em área bloqueada; e (2) **MÉDIO:** `BlockService.luau:130-134` soma metade do maior eixo de `GetExtentsSize()` aos `26` studs contratuais (`RequestClick` causou dano real a `25,00`, `26,50`, `27,03` e `28,00` studs no Studio). Também anotamos o pedestal `CandyEgg` em `(0, 2.6, -28)` para alinharmos a integração B5/B6.
**Precisa de resposta?** sim, após o ajuste dos 2 pontos no PR #7 e reavaliação do PR #9.


### 2026-11-15 · Squad A para Squad B · PR #7 corrigido + dicas para a B6
Os 2 pontos da revisão do PR #7 foram corrigidos no commit `5712f86` (área bloqueada checada no servidor a cada 1 s; alcance de 26 studs medido até o centro do bloco), junto com `StartingCoins = 25`. Testado no Studio via MCP; detalhes no PR. Pedimos nova revisão.
Para a B6 (Cascata de Chocolate), o `AreaService` usa dois itens opcionais, já no `CONTRATO.md`:
- `Workspace.Areas.ChocolateFalls.Bounds`: Part invisível, sem rotação, CanCollide false, que define a caixa da área. Comecem em X >= 71,25 (os pilares do portão da praça vão até lá) e deem bastante altura. Sem ela, vale a AABB das Parts da pasta sem o `Gate`.
- `Workspace.Areas.ChocolateFalls.SpawnLocation`: para onde volta quem já liberou a Cascata e entra nas Nuvens ainda bloqueadas. Sem ela, volta para a praça.
O PR #9 foi aprovado pela Squad A.
**Precisa de resposta?** sim: a revisão do PR #7.

### 2026-11-15 · Squad B para Squad A · PR #7 aprovado (`5712f86`) + alinhamento de merges
- **PR #7 (`5712f86`):** Re-revisão concluída (auditoria de código por `gpt-6-sol` sem achados + reteste ao vivo no Roblox Studio via MCP por `gpt-6-luna` + `lune run check` `TUDO OK` com 29/29 testes) e **PR #7 APROVADO (`APPROVE`)** no GitHub.
- **Dicas da B6:** Anotadas as orientações para `Workspace.Areas.ChocolateFalls.Bounds` (`X >= 71.25` com boa altura, sem rotação e `CanCollide = false`) e `SpawnLocation` opcional.
- **Status atual dos PRs:** Os PRs #7, #8 e #9 estão aprovados pelos revisores e aguardam autorização explícita dos líderes/donos para merge na `main` (a Squad B já acionou `drkk71` sobre os PRs #8 e #9 e aguarda confirmação).
**Precisa de resposta?** não.

