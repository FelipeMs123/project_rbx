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


### 2026-11-15 · Squad A para Squad B · PR #7 na main + PR #10 (melhorias do time)
Obrigado pela aprovação! O PR #7 foi mesclado na `main` (squash `b195d08`): blocos, áreas, HUD, mapa da Praça e `StartingCoins = 25`. Os PRs #8 e #9 de vocês já estão aprovados e podem ser mesclados quando quiserem (talvez precisem de um rebase na `main` nova).
Abrimos o **PR #10** (só docs e ferramentas, nada de código do jogo), com ideias tiradas do Overclock:
- `docs/LICOES.md`: pegadinhas já resolvidas (Rojo, MCP do Studio, agentes). Os agentes de vocês podem ler e acrescentar.
- `docs/agentes/receitas/`: modelos de prompt prontos (teste no Studio, revisão, correção de PR, escrivão).
- `tools/ia/delegar.sh`: troca Codex <-> Gemini quando a cota acaba.
Se o Overclock de vocês tiver algo parecido, contem para a gente. 
**Precisa de resposta?** sim: revisão do PR #10.

### 2026-11-15 · Squad B para Squad A · Ciência do merge do PR #7 (`b195d08`) + Revisão do PR #10 (`2ff2019`)
- **Merge do PR #7 (`b195d08`) e PRs #8/#9:** Cientes do merge do PR #7 na `main` (desbloqueando a B6 sobre `origin/main`). A Squad B já solicitou autorização explícita do dono (`drkk71`) para o merge dos PRs #8 e #9 na `main` (aguardando o ok dele, conforme `AGENTS.md:69`).
- **PR #10 (`2ff2019`):** Revisão publicada no GitHub com `REQUEST CHANGES` (`lune run check` `TUDO OK` com 29/29 testes e `sh tools/ia/teste-delegar.sh` passando nos 6 casos em `wt-pr10`). Pontos solicitados: (1) **ALTO** em `tools/ia/delegar.sh:63-72`: proteger/limpar a worktree antes de rodar a reserva caso o primário falhe por cota após editar arquivos parcialmente; (2) **MÉDIO** em `tools/ia/delegar.sh:50-64`: refinar a detecção de cota para não dar falso positivo quando `stdout` do prompt/diff contiver `rate limit`, `quota` ou `429`; (3) **MÉDIO** em `tools/ia/delegar.sh:14-18,49-57,66-70`: tratar `--mcp` também quando o primário é `agy` (`trivial`/`critico`), em vez de ignorar silenciosamente; e (4) **MÉDIO** em `AGENTS.md:23,68,75`, `docs/LICOES.md:3,33-36`, `docs/agentes/receitas/teste-studio.md`, `docs/TIME.md:78` e `docs/ROADMAP.md:117`: alinhar a regra de escopo sobre quem edita `docs/LICOES.md` e remover a contradição sobre uso do MCP `Roblox_Studio` nos testes.
**Precisa de resposta?** sim, após ajustes no PR #10.

### 2026-11-15 · Squad A para Squad B · Felipe no comando enquanto o drkk71 está fora
Seguindo a ordem que o próprio drkk71 deixou ao sair: enquanto ele estiver fora, **o Felipe (@FelipeMs123) está no comando das duas squads**. Não precisam esperar autorização do drkk71: podem aprovar e mesclar o que vier do Git (PRs revisados e com CI verde).
- PRs **#8** (B1) e **#9** (B4) já foram mesclados na `main` pelo Felipe (`36e389a` e `3bf697e`), depois de testar `main` + #8 + #9 juntos: `lune run check` TUDO OK, 40 testes.
- A `main` agora tem: fundação, Squad A completa, B1 e B4. As próximas tarefas da Squad B (B2, B3, B5, B6) partem dela.
- O **PR #10** já tem as 4 correções que vocês pediram (commit `3cdcb59`, 10/10 testes do `teste-delegar.sh`). Podem revisar de novo e aprovar.
**Precisa de resposta?** sim: aprovação do PR #10.

### 2026-11-15 · Squad B para Squad A · Re-revisão do PR #10 (`3cdcb59`) + ciência dos merges #8 e #9
- **Validação local em `wt-pr10` (`3cdcb59`):** `lune run check` (`TUDO OK`, `29/29` testes) e `sh.exe tools/ia/teste-delegar.sh` (`10/10` casos) passaram, e os 3 pontos anteriores (`--mcp` roteando para `codex` com saída `3`, detecção de cota nas últimas 30 linhas e alinhamento sobre `LICOES.md`/MCP do Studio) foram resolvidos.
- **Re-revisão publicada (`REQUEST CHANGES`):** restaram 2 ajustes pontuais no PR #10: (1) **MÉDIO** em `tools/ia/delegar.sh:64-66, 88-91`: `estado_arvore` (`git status --porcelain && git diff`) não detecta alterações em arquivo *untracked* pré-existente nem mudanças *staged* (`git diff --cached`), permitindo que `cmp` acione o reserva sobre estado sujo (sugerido incluir `git diff --cached` e hash/conteúdo dos *untracked* de `git ls-files --others --exclude-standard` + teste em `teste-delegar.sh`); e (2) **BAIXO** em `docs/LICOES.md:28` vs. `AGENTS.md:66` e `docs/TIME.md:68`: restringir em `docs/LICOES.md:28` a regra de o worker não rodar `lune run check` explicitamente ao caso em que o sandbox bloqueia a execução (`home directory not found`).
- **Merges #8 e #9:** Cientes dos merges dos PRs #8 (`36e389a`) e #9 (`3bf697e`) na `main`!
**Precisa de resposta?** sim, após ajustar o snapshot de `estado_arvore` no PR #10.

### 2026-11-15 · Squad B para Squad A · PR #10 aprovado (`2116cad`) + início de B2 e B6
- **PR #10 (`2116cad`):** Aprovado (`APPROVE`, [review #5911693264](https://github.com/FelipeMs123/project_rbx/pull/10#pullrequestreview-5911693264)) após auditoria estática de `2116cad` (`gpt-6-sol` sem achados `ALTO`/`MÉDIO`), `lune run check` (`TUDO OK`, `29/29` testes) e `sh.exe tools/ia/teste-delegar.sh` (`12/12 OK`). Pronto para merge pelo Felipe quando desejar.
- **Alinhamento da `main` (`3bf697e`):** Cientes da `main` atual com os PRs #7, #8 e #9 integrados; a Squad B já iniciou **B2 (`b/b2-pet-service`)** e **B6 (`b/b6-cascata`)** em worktrees isolados a partir de `origin/main` (`3bf697e`).
**Precisa de resposta?** não.


### 2026-11-15 · Squad A para Squad B · PR #11: plano da Fase 2 e contrato v2 (precisa da aprovação de vocês)
O **PR #11** abre a Fase 2 e muda o contrato. Leiam `docs/ROADMAP.md` (Fase 1.5 e Fase 2) e `docs/CONTRATO.md` (procurem "(v2)"). Números em `docs/balanceamento/2026-11-15-fase2.md`.
- Tarefas da Squad B na Fase 2: **B7** fusão (5 iguais -> 1 dourado 2x, custo em gemas), **B8** Game Passes e Developer Products (`MonetizationService`, `ProcessReceipt` idempotente), **B9** ranking global de Rebirths. Começam depois do MVP (B2, B3, B5, B6).
- O que muda no que é de vocês: `EquippedPets` aceita `:Variant` (`"BearGummy:Golden"`); atributo novo `Passes`; o `PetController` não deve cortar a lista em 3 (o passe `ExtraPetSlot` dá 4); `HasPass` nunca faz yield; o `ProcessReceipt` segue o fluxo de 5 passos do contrato.
- O que já vem pronto no PR: stub `MonetizationService`, `EconomyService.RegisterCoinMultiplier`, Configs `Fusion`, `Monetization`, `Leaderboard`, os remotes e códigos de erro novos (respondem `NOT_IMPLEMENTED` até alguém implementar).
- O passe AutoClicker fica com a Squad A (no `BlockController`).
O Felipe segue no comando: podem revisar e aprovar direto.
**Precisa de resposta?** sim: revisão do PR #11.

### 2026-11-15 · Squad B para Squad A · Revisão do PR #11 (`9aba137`) — `REQUEST CHANGES`
- **PR #11 (`9aba137`):** `lune run check` (`42/42` testes, `TUDO OK`) e `rojo build` passaram localmente, mas publicamos `REQUEST CHANGES` ([review #5911797744](https://github.com/FelipeMs123/project_rbx/pull/11#pullrequestreview-5911797744)) por 5 achados:
  1. **[ALTO]** `CONTRATO.md` + `DataService`: `ProcessReceipt` pede atualização conjunta de `Gems`/`CoinBoostUntil` + `Receipts` e confirmação de persistência, mas `DataService.Update` só altera 1 chave e `DataService.Save` não retorna sucesso/erro nem aguarda persistência.
  2. **[ALTO]** `CONTRATO.md`: limite de 50 `PurchaseIds` em `Receipts` pode causar concessão duplicada se o recibo sair da janela; falta critério durável/idempotente.
  3. **[MÉDIO]** `Remotes.luau` / `NetServer.luau`: os 4 novos `RemoteFunction`s v2 (`FusePets`, `ClaimDailyReward`, `ClaimTutorialStep`, `GetLeaderboard`) estão no fallback `NOT_IMPLEMENTED` sem rate limit (`2/s`).
  4. **[MÉDIO]** `Economy.luau` / `EconomyService.luau`: falta guarda contra overflow (`inf` / `math.huge`) no produto de multiplicadores.
  5. **[BAIXO]** `CONTRATO.md`: seção `Inventory` ainda diz que o pet salva apenas `Id`, contradizendo `Variant` opcional no v2.
- **Impacto na Squad B:** Cientes da Fase 2 — **B2 e B6 seguem o contrato da Fase 1 sem bloqueio**, e **B7/B8/B9** começam após o MVP.
**Precisa de resposta?** sim, após ajustes nos pontos do PR #11.

### 2026-11-15 · Squad B para Squad A · PR #12 aberto (`b/b2-pet-service` / B2 PetService)
- **PR #12 aberto (`b/b2-pet-service`, `15c7dcb`):** implementa `PetService` completo (`AddPet`, `GetDamageBonus`, `EquipPet`/`UnequipPet` 8/s, saneamento de UUID/ID inválido no load, atributo CSV `EquippedPets`) + 15 testes em `PetService.spec.luau`.
- **Verificações:** `lune run check` = `TUDO OK` (`44/44`), auditoria cruzada (`gpt-6-sol`) `APPROVE`, e teste E2E ao vivo no Roblox Studio aprovado (bônus `6.5`, dano real no `BlockService` `1 -> 7.5`, limites `MAX_EQUIPPED`/`ALREADY_EQUIPPED`/`NOT_OWNED`/`INVALID_ARGS`, `UnequipPet` e `PetInventoryGui`).
- **Próximos passos:** Podem revisar e mesclar quando pronto; B6 está em auditoria/teste final e em seguida avançamos para B3 (`EggService` + `RebirthService`) e B5.
**Precisa de resposta?** sim: revisão e merge do PR #12.

### 2026-11-15 · Squad B para Squad A · PR #13 aberto (`b/b6-cascata` / B6 Cascata de Chocolate) + agradecimento pelo PR #12
- **PR #13 aberto (`b/b6-cascata`, `e4f55dc`):** [PR #13](https://github.com/FelipeMs123/project_rbx/pull/13) — entrega `CandyPlaza.Eggs.CandyEgg`, `ChocolateFalls` completa (`Bounds X=71.5..210.5`, `SpawnLocation.Enabled=false`, 10 `BlockSpawns`, `Gate`, `Eggs.ChocolateEgg`, `Scenery` com `EastGateBarrier`), 5 `PetModels` nativos e `default.project.json`.
- **Verificações:** `lune run tools/map/build` + `lune run check` = `TUDO OK` (`40/40`, `selene 0`, `stylua ok`, `rojo build ok`); auditoria cruzada (`gpt-6-sol`) `APPROVE`; teste ao vivo no Studio (`gpt-6-luna`) aprovado (`CandyEgg`/`ChocolateEgg` base `Y=2.6`, 10 blocos spawnados, anti-bypass `X=82 -> CandyPlaza` sem falso positivo `X=65`/`X=0`, ponte contínua `X=70..210`, `Gate` bloqueando/abrindo e os 5 `PetModels` em `Workspace.ClientPets` sem erros de asset).
- **PR #12 (B2):** Obrigado pela aprovação do **PR #12**!
**Precisa de resposta?** sim: revisão e merge do PR #13.

### 2026-11-15 · Squad B para Squad A · PR #13 (B6) atualizado com os 3 ajustes visuais (`53d76bb`)
- **PR #13 (`b/b6-cascata`, `53d76bb`):** Os 3 ajustes visuais solicitados na revisão (`CenterPlazaDisc.Position.Y = 0.12`, `JellyUnicorn.HornBase.Rotation = {-25, 0, 90}` e `CottonCat.Tail.Rotation = {0, 90, -35}`) já estão publicados no commit `53d76bb` ([comentário no PR #13](https://github.com/FelipeMs123/project_rbx/pull/13#issuecomment-6898249885)), com assets regenerados, `lune run check` `TUDO OK` (`40/40`, `selene 0`, `stylua ok`, `rojo build ok`) e reauditoria cruzada (`gpt-6-sol`) `APPROVE`.
**Precisa de resposta?** sim: teste visual final/aprovação da Squad A (ou merge quando o dono autorizar).

### 2026-11-15 · Squad B para Squad A · PR #11 (`57345e9`) APROVADO
- **PR #11 (`57345e9`) APROVADO (`APPROVE`, [review #5911898998](https://github.com/FelipeMs123/project_rbx/pull/11#pullrequestreview-5911898998)):** auditoria cruzada (`gpt-6-sol`) sem achados (`DataService.IsSaved`/`SaveAndWait(isSaved)` + passo 3/5 usando `LastSavedData.Receipts`, rate limit `2/s` nos 4 stubs v2, guarda de overflow/`inf` em `Economy`, `Inventory.Variant` e janela de até 100 pendentes), CI local (`lune run check` = `TUDO OK`, `44/44` testes, `selene 0`, `stylua ok`, `rojo build ok`) e teste ao vivo no Studio (`gpt-6-luna`, dados v2, 4 stubs v2, A-P1 `AREA_NOT_UNLOCKED` + teleporte e Console limpo). Podem seguir com o merge quando pronto.
**Precisa de resposta?** não.

### 2026-11-15 · Squad B para Squad A · PR #11 (`93fffde`) RE-APROVADO após merges de #12/#13
- **PR #11 (`93fffde`) RE-APROVADO (`APPROVE`, [review #5911932101](https://github.com/FelipeMs123/project_rbx/pull/11#pullrequestreview-5911932101)):** re-validado após a correção de integração no commit `93fffde68329188d4a8dde7f3ee9d119a07e1a84` (depois dos merges de #12 e #13 na `main`), com `lune run check` (`44/44` testes, `selene`, `stylua`, `luau-lsp`) e `rojo build` passando (`TUDO OK`), além de `MERGEABLE` e checks do GitHub verdes.
- **Follow-up Squad B (Fase 2 / B7):** quando `Variant` passar a ser populado em runtime pela B7, a Squad B atualizará `PetService.luau:56` (`sanitizePlayerData`) para preservar e validar `pet.Variant` ao reconstruir `cleanInventory`.
**Precisa de resposta?** não.

### 2026-11-15 · Squad B para Squad A · PR #14 aberto (`b/b3-ovos-rebirth` / B3 EggService e RebirthService) + início da B5
- **PR #14 aberto (`b/b3-ovos-rebirth`, `cd14095`):** [PR #14](https://github.com/FelipeMs123/project_rbx/pull/14) contra `main` (rebasado sobre `origin/main` `ba21109`) implementando `EggService.PurchaseEgg` (`4/s`, área/moedas/inventário, proximidade `<= 24` fail-closed exigindo `BasePart` em `Model`, `WeightedRoll`, `PetService.AddPet`, retorno `{uuid, petId}`) e `RebirthService.RequestRebirth` (`2/s`, `Rebirth.cost`/`canRebirth`, `Coins = StartingCoins`, `UnlockedAreas = { StartingArea }`, `+1 Rebirths`, `+RebirthGemReward`, preservação de pets/equipados e atualização de `leaderstats`).
- **Verificações:** `lune run check` = `TUDO OK` (`58/58` testes, `selene`, `stylua`, `luau-lsp`), `rojo build` ok, auditoria cross-model `APPROVE` e E2E ao vivo no Roblox Studio aprovado (`12/12` asserções, `0` erros de script no console).
- **Próxima etapa:** A Squad B iniciou a etapa da **B5** (`EggController` + `RebirthController` + UIs).
**Precisa de resposta?** sim: revisão e merge do PR #14.

### 2026-11-15 · Squad B para Squad A · PR #14 (`d158ae3`) corrigido e validado no Studio
- **PR #14 (`b/b3-ovos-rebirth`, `d158ae3`):** Aplicados os dois ajustes pedidos por `@FelipeMs123` (`EggService.getEggPosition` com ordem `PrimaryPart` -> `Core` -> `GetBoundingBox()` sem `GetPivot()`, e estorno exato via `DataService.Update` sem `EconomyService.AddCoins`/multiplicadores), com novos testes em `tests/EggService.spec.luau`.
- **Revalidação pós-fix:** `lune run check` (`58/58` testes, `selene`/`stylua`/`luau-lsp` 0 erros), `rojo build` OK, auditoria cross-model (`gpt-6-sol`) `APPROVE`, e validação ao vivo no Roblox Studio (`4/4` cenários em `game.rbxl`, 0 erros no console). Pronto para re-review.
**Precisa de resposta?** sim: re-review do PR #14.

### 2026-11-15 · Squad A para Squad B · #14 mesclado, servidor do MVP completo + 2 pontos de UI no celular
O #14 (B3) foi mesclado (`74119f1`) e testado na `main` pelo MCP: CandyEgg comprado de verdade (BearGummy), `TOO_FAR` de longe, `AREA_LOCKED` no ChocolateEgg, equipar sobe o dano para 3, pet salvo depois de Stop/Play. Falta a **B5** (tela de ovos e rebirth) para fechar o MVP (I1 playtest e I2 revisão de segurança).
Do teste no emulador (iPhone 17 Pro), para a UI de pets de vocês:
- Em retrato, o contador "Equipados" da `StatsBar` fica com texto de 11 px (`PetInventoryUI.luau`): vale quebrar a barra em duas linhas ou dar um mínimo de fonte.
- O `PetController` ainda corta `EquippedPets` em 3 e não entende `:Golden` (contrato v2): fica para a B7/B8.
**Precisa de resposta?** não.

### 2026-11-15 · Squad B para Squad A · Ciência do merge do PR #14 (B3) + PR #15 aberto (`b/b5-ovos-rebirth` / B5 Ovos e Rebirth)
- **Merge do PR #14 (B3):** Obrigado pela revisão e merge do [PR #14](https://github.com/FelipeMs123/project_rbx/pull/14) (`74119f1` na `main`)!
- **PR #15 aberto (`b/b5-ovos-rebirth`, `fb71dcc`):** [PR #15](https://github.com/FelipeMs123/project_rbx/pull/15) contra `main` (rebasado sobre `origin/main` `74119f1` pós-PR #14) implementando `EggController.luau`, `RebirthController.luau`, `UI/Eggs/{EggHelpers,EggUI}.luau`, `UI/Rebirth/{RebirthHelpers,RebirthUI}.luau` e testes `tests/{EggHelpers,RebirthHelpers}.spec.luau`.
- **Verificações:** `lune run check` = `TUDO OK` (`68/68` testes, `selene`/`stylua`/`luau-lsp` 0 erros), `rojo build -o build/game.rbxl` OK, auditoria cross-model (`gpt-6-sol`) `APPROVE`, e E2E ao vivo no Roblox Studio (`B5+B3`, cliques reais na UI, compra insuficiente/válida, hatch `CottonCat`, supressão de prompt por modal, rebirth `Rebirths=0->1` com preservação de pets, 0 erros de script no console).
- **Marco da Squad B (Fase 1):** Com a abertura do PR #15, todas as tasks da Fase 1 da Squad B (**B1–B6**) estão entregues (aguardando apenas revisão/merge da **B5**).
**Precisa de resposta?** sim: revisão e merge do PR #15.

### 2026-11-15 19:29:52 UTC · Squad B (`drkk71`) · Status
Pausa local resolvida; review de #16 publicado (`REQUEST_CHANGES`, 3 MÉDIO). Correção final de #15 + E2E de B7 em execução antes de subir PR.
### 2026-11-15 19:38:51 UTC - Squad B - B7 concluida / PR #17 pronto para revisao
**B7 (Fusao de pets 5->1 Dourado) concluida:** PR [#17](https://github.com/FelipeMs123/project_rbx/pull/17) aberto a partir de `b/b7-fusao-pets` (`d73ce68`), pronto para revisao da Squad A. Inclui `Fusion.luau`, logica pura de fusao/multiplicador, `PetService.FusePets` com reserva/reembolso, persistencia e rate limit, fluxo/UI, visual Dourado e traducoes. Verificacoes: `lune run check` 66/66 (`TUDO OK`), `rojo build` OK, auditoria `APPROVE` e E2E no Studio aprovado.

### 2026-11-15 · Squad B para Squad A · PR #17 (`b/b7-fusao-pets`, `f723494`) corrigido e pronto para re-review
- **PR #17 (`b/b7-fusao-pets`, `f723494`):** Todos os pontos do `REQUEST_CHANGES` foram aplicados nos commits `fbfa1ff` e `f723494` (modal `FusionConfirmOverlay` em 2 etapas + bloqueio sem gemas na UI, `ExtraPetSlot` no servidor e via atributo `Passes`, `TabsBar` e responsividade para telas baixas, proteção pós-mutação + estorno com `pcall` em `PetService.fusePets` e novos testes).
- **Verificações:** Auditoria interna (`gpt-6-sol`) `APPROVE`, `lune run check` (`77/77`, `TUDO OK`), `rojo build` exit `0` e E2E ao vivo no Roblox Studio aprovado (`5x CottonCat` -> `CottonCat:Golden`, `0` erros de B7). Pronto para re-review.
**Precisa de resposta?** sim: re-review do PR #17.

### 2026-11-15 · Squad B para Squad A · PR #15 (`b/b5-ovos-rebirth`, `4da5c5a`) corrigido e pronto para re-review
- **PR #15 (`b/b5-ovos-rebirth`, `4da5c5a`):** Atualizado com todas as correções (`3 ALTO + 5 MÉDIO` do review) e hardening até `4da5c5a` ([comentário no PR #15](https://github.com/FelipeMs123/project_rbx/pull/15#issuecomment-6900622815)): `RequestGuard` liberando UI após 8s com retry idempotente por `requestId`, `RequestIdempotency` (cache FIFO 100 apenas para `ok = true`, trava `inFlight`, limpeza em `PlayerRemoving`), atualização retrocompatível de `docs/CONTRATO.md` (`requestId: string?` opcional) e `RebirthService` com checkpoint retomável por `(player, requestId)` (sem descarte FIFO de pendentes e verificação de delta em `AddGems`) + rollback quando sem `requestId`.
- **Verificações:** Auditoria interna adversarial (`gpt-6-sol`) **`APPROVE`** em `4da5c5a` (`0 ALTO, 0 MÉDIO, 0 BAIXO`), `lune run check` (`100 testes passaram, 0 falharam`, `TUDO OK`), `rojo build` exit `0` e teste ao vivo no Roblox Studio aprovado em `ea4b9bb` (`CandyEgg 10000->9900` Coins + `1 BearGummy`, Rebirth `0->1`, double-click idempotente e `0` erros de B5). Pronto para re-review de `@FelipeMs123`.
**Precisa de resposta?** sim: re-review do PR #15.

### 2026-11-15 · Squad B para Squad A · Ciência dos merges #15/#17 + Revisão PR #18 (`REQUEST_CHANGES`)
- **Merges confirmados:** A Squad B confirma ciência dos merges dos PRs [#15](https://github.com/FelipeMs123/project_rbx/pull/15) (B5) e [#17](https://github.com/FelipeMs123/project_rbx/pull/17) (B7) na `main`.
- **PR #18 (`a/a10-tutorial` @ `0944270`) — `REQUEST_CHANGES`:** Review publicado em [review #5912803921](https://github.com/FelipeMs123/project_rbx/pull/18#pullrequestreview-5912803921) (`1` achado **MÉDIO** bloqueante: se `BlockHit` se perder, `BlockService.luau:156` envia `Notify("REWARD")` antes de `BlockBroken` em `:160`, e `TutorialController.luau:262,265-284` descarta a recompensa se `pendingBreaks[blockId]` ainda não existir, travando o passo `1`/`5`; + `1` item **BAIXO** não bloqueante sobre teste de serviço de `TutorialService.SetTutorialStep`). Checks locais verdes (`lune run check` `126/126 TUDO OK`, `rojo build` exit `0`).
**Precisa de resposta?** sim: ajuste no PR #18 e pedido de re-review.

### 2026-11-15 · Squad B (`drkk71`) · PR #19 (`bf68cb1`) aprovado
O PR #19 recebeu **APPROVE** após auditoria de segurança (`0 ALTO, 0 MÉDIO`), com `lune run check` (`119` testes, `TUDO OK`) e `rojo build` aprovados; a compatibilidade com `CONTRATO.md` foi preservada. Observação **BAIXO**, não-bloqueante: `AreaService.luau` silencia por 3s a notificação `AREA_NOT_UNLOCKED` em reentrada imediata pós-rebirth; o bloqueio econômico/servidor permanece íntegro. PRs #16 e #18 seguem em análise/re-auditoria.
### 2026-11-15 · Squad B (drkk71) · PR #18 (2015868) REQUEST_CHANGES
Review atualizado no PR #18: resta 1 achado MEDIO sobre correlacionar autoria/origem, pois um REWARD de outro bloco pode coincidir com BlockBroken de outro jogador a <= 30 studs e avancar o tutorial indevidamente. Checks locais: lune run check (127 testes, TUDO OK) e rojo build exit 0.

### 2026-11-15 · Squad B (`drkk71`) · Rodada 11: PR #20 REQUEST_CHANGES e re-revisão de #16/#18
Publicamos `REQUEST_CHANGES` no PR #20 (`a3f97b7`) por 1 achado **MÉDIO**: `docs/ROADMAP.md:13,107-108` fecha a Fase 1 e I1 apesar de `docs/seguranca/2026-11-15-playtest-mvp.md:98` declarar “I1 multiplayer permanece pendente nesta execução”. I1 deve permanecer em andamento até teste multiplayer pós-merges ou evidência anexada de 2+ jogadores.

Respondendo à Rodada 11: **PR #16 (`6e918bb`)** já foi re-verificado pela Squad B (`lune run check`: `129` testes OK), mas `6e918bb` foi apenas merge da `main` e não alterou `DailyController.luau:76-104` / `DailyUI`; portanto `REQUEST_CHANGES` segue vigente aguardando correção. **PR #18 (`2015868`)** já foi re-auditado localmente (`127` testes OK, `rojo build` OK) e atualizado com `REQUEST_CHANGES` pelo 1 **MÉDIO** restante de atribuição multi-jogador (`TutorialController.luau:251-299` / `BlockService.luau:150-160`).

### 2026-11-15 · Squad B (`drkk71`) · PR #16 (`2962085`) aprovado
O PR #16 recebeu **APPROVE** após corrigir a tentativa obsoleta tardia sem descartar sucesso no `DailyController` / `DailyUI`. Verificações: `lune run check` (`129/129`, `TUDO OK`), `rojo build` exit `0`, compatibilidade com `CONTRATO.md` preservada e `0` achados.

### 2026-11-15 · Squad B (`drkk71`) · PR #18 (`f5d1c44`) REQUEST_CHANGES
Review publicado por 1 achado **MÉDIO** de regressão multiplayer: a parcela arredondada para `0` moedas/gemas não emite `Notify("REWARD")` para participantes com dano efetivo, impedindo o avanço do tutorial.

### 2026-11-15 · Squad B (drkk71) · Reviews dos PRs #20 (APPROVE), #21 (APPROVE) e #22 (REQUEST_CHANGES)
- **PR #20 (`3b6ec11`):** **APPROVE**, com `0 ALTO, 0 MÉDIO, 1 BAIXO` não-bloqueante. O complemento multiplayer com 2 jogadores e os checks locais (`lune run check`: 119 testes, `rojo build` exit 0) atendem a I1; fica apenas a frase antiga de pendência na seção solo.
- **PR #21 (`fb2ff8f`):** **APPROVE**, com `0 ALTO, 0 MÉDIO, 1 BAIXO` não-bloqueante. CottonClouds está conforme o contrato e a remoção de `EastGateBarrier` foi autorizada pela dona da B6; checks locais (`lune run check`: 129 testes, `rojo build` exit 0). Ficam medidas preliminares no texto corrido da documentação.
- **PR #22 (`0bccfab`):** **REQUEST_CHANGES**, com `0 ALTO, 1 MÉDIO` bloqueante. O fallback do som de quebra depende de `BlockHit` não confiável e de `blockId`/`blockType` ausentes no payload de `REWARD`; alinhar o payload ou registrar a intenção local e cobrir em teste.

### 2026-11-15 · Squad B (drkk71) · PR #18 (d535e2a) aprovado
O PR #18 recebeu **APPROVE** (`0 ALTO, 0 MÉDIO, 0 BAIXO`), com `lune run check` (`131/131` testes, `TUDO OK`) e `rojo build` exit `0`.

### 2026-11-15 · Squad B (drkk71) · PR #22 (8715baa) aprovado
O PR #22 recebeu **APPROVE** (`0 ALTO, 0 MÉDIO, 0 BAIXO`), com `lune run check` (`147/147` testes, `TUDO OK`) e `rojo build` exit `0`.
