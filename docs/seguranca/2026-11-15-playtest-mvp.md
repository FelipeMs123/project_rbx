# I1 — Playtest do MVP completo

Data: 15/11/2026. Resultado: **✅ ciclo individual e persistência aprovados, com ressalvas de cobertura e asset**.

## Ambiente e método

- Branch `main`, HEAD `1bc68fcfb2c0a8543a55a33c2aee722503b787a8`; conexão Rojo à main informada pelo humano.
- Place **Candy Smash Simulator**, PlaceId `137544077538328`, UniverseId `10776936914`; começou e terminou em **Edit**.
- Teste pelo MCP Roblox_Studio, datamodel **Client**, com `FireServer`/`InvokeServer` e `Character:PivotTo`. Nenhum Service requerido pelo MCP, nenhuma alteração direta de saldo ou dados.
- Perfil real do humano, com autorização para gastar e fazer rebirth. Output nas duas sessões: `[Server] Candy Smash Simulator iniciado (8 services)` e `[profilestore]: Roblox API services available - data will be saved`.
- Cliques espaçados por `task.wait(0.07)` (até aproximadamente 14,3/s), compras espaçadas, um pedido de rebirth. Farm em chamadas de até 55 s, sempre com yield; GetData entre blocos, com espera de 0,5 s. Preferência por LollipopBlock na praça e ChocoBlock na cascata.
- Tempo total entre primeiro Play e Stop final: **aproximadamente 9 min 21 s**, incluindo consultas, pausas e reconexão.
- Não foram editados arquivos em `src/`, nem feito commit. O relatório preexistente `2026-11-15-revisao-mvp.md` foi preservado.

## Ciclo medido

| Passo | Resultado | Antes | Depois / evidência |
|---|---|---|---|
| 1. Play e GetData | ✅ | Edit | 8 services; salvamento real disponível; Coins 86, Gems 2, Rebirths 0; 1 pet no inventário e equipado; áreas `[CandyPlaza]`; Daily `{LastClaimDay=20772, Streak=1}`; TutorialStep 0 |
| 2a. Farm para comprar pets | ✅ | 86 moedas | 226 moedas; 7 blocos, 78 solicitações de clique, 11,56 s |
| 2b. Comprar e equipar | ✅ | 226 moedas; 1 equipado | Dois CandyEgg de 100: LollipopBunny e CottonCat; quatro retornos `ok=true` (duas compras e duas equipagens); saldo 26; 3 equipados |
| 2c. Dano | ✅ | BearGummy, bônus 2 | BlockHit mediu **7,5** com os três: `1 + 2 + 3 + 1,5` |
| 3a. Farm da praça | ✅ | 26 moedas | 802 → 1.674 → **1.808**; 109 blocos e 430 solicitações de clique; 114,32 s |
| 3b. UnlockArea | ✅ | 1.808 moedas; `[CandyPlaza]` | `UnlockArea("ChocolateFalls")`: `ok=true`, `data.areaId="ChocolateFalls"`; **8 moedas**; áreas `[CandyPlaza, ChocolateFalls]` |
| 3c. Gate no Client | ✅ | Core com Transparency 0,25; outras quatro peças 0; todas CanCollide true | Após 0,6 s: Core, BarNorth, FrameTopBeam, CaramelStripeCenter e BarSouth com **Transparency 1 e CanCollide false**; Parent continuou `Gate` |
| 3d. Entrar na cascata | ✅ | Teleporte para `(100,6,0)` | Após 2 s, posição `(100,3.2075,0)`; permaneceu na área, sem expulsão |
| 3e. Recompensas da cascata | ✅ | Coins 8, Gems 2 | 24 ChocoBlocks: Coins **2.528**, Gems **26**; +2.520 moedas e +24 gemas em 57,41 s |
| 4. ChocolateEgg | ✅ | Coins 2.528; 3 pets | Config/Eggs confirma **2.500 moedas**; próximo ao Core `(140,5,-28)`, compra `ok=true`, pet **BearGummy**; Coins **28**; 4 pets, 3 equipados |
| 5. Fusão | ⚠️ | Só quatro pets no total; um desequipado | **Não testado**: não havia cinco pets iguais desequipados. FusePets não foi chamado |
| 6a. Farm do rebirth | ✅ | Coins 28, Gems 26, Rebirths 0 | Coins 2.233 → 4.438 → 6.643 → 8.848 → **10.003**; Gems **121**; 95 ChocoBlocks; 226,97 s |
| 6b. RequestRebirth | ✅ | Coins 10.003, Gems 121, Rebirths 0; duas áreas | `ok=true`, `data={rebirths=1,gemsReward=5}`; **Coins 25, Gems 126, Rebirths 1**, áreas `[CandyPlaza]`; inventário e equipados preservados |
| 6c. Bônus de moedas | ✅ | Coins 25; GummyBlock inteiro com HP 12 | Dois BlockHit com damage 7,5, HP 4,5 → 0; Coins **37**: +12 = `floor(8 × (1 + 1 × 0,5))`, contra 8 sem rebirth |
| 7. Persistência | ✅ | Estado final: Coins 37, Gems 126, Rebirths 1 | Stop, espera medida de **16,5 s** (incluindo espera explícita de 12 s), Play, GetData: todos os campos iguais, inclusive UUIDs e ordem dos equipados |
| 8. Console | ⚠️ | API disponível e 8 services | Sem stack trace de script ou erro de DataStore observado; seis avisos de asset incompatível em cada sessão, detalhados abaixo |
| 9. Encerramento | ✅ | Segunda sessão em Play | `start_stop_play(false)`; `get_studio_state` confirmou **Edit**, somente datamodel Edit disponível |

Config/Game conferida: StartingCoins 25, RebirthBaseCost 10.000, RebirthCostGrowth 2,5, RebirthCoinBonus 0,5 e RebirthGemReward 5. Com Rebirths inicial 0, o custo calculado era 10.000.

**Ressalva de design:** a descrição do roteiro dizia que ChocoBlocks dão gemas “às vezes”, mas Config/Blocks define `Gems = 1` fixo. Os 119 ChocoBlocks quebrados no teste deram exatamente 119 gemas. Isso corresponde à configuração atual; não foi observado sorteio de gemas.

## Tempos para balanceamento

| Trecho | Tempo ativo nos loops de farm | Medida |
|---|---|---|
| Completar dinheiro para dois CandyEgg | 11,56 s | 86 → 226; gasto posterior de 200 |
| Praça após equipar três pets | 114,32 s (1 min 54 s) | 26 → 1.808; aproximadamente 15,6 moedas/s |
| Farm acumulado até poder comprar cascata | **125,89 s (2 min 06 s)** | Inclui farm para os ovos; exclui compras, consultas e pausas |
| Cascata para ChocolateEgg | 57,41 s | 8 → 2.528; compra posterior por 2.500 |
| Cascata após ChocolateEgg até rebirth | **226,97 s (3 min 47 s)** | 28 → 10.003; aproximadamente 43,9 moedas/s |
| Farm acumulado desde entrada na cascata até poder fazer rebirth | **284,38 s (4 min 44 s)** | Inclui os 2.500 gastos no ChocolateEgg |
| Farm acumulado da sessão até poder fazer rebirth | **410,27 s (6 min 50 s)** | Inclui os dois CandyEgg, a área e o ChocolateEgg |

Entre iniciar o farm da praça com três pets e chegar à chamada de desbloqueio decorreram aproximadamente 129,6 s de relógio; entre iniciar o farm após ChocolateEgg e chegar à chamada de rebirth, 259,6 s. Esses valores incluem intervalos entre ferramentas.

**Limite da medição:** houve teleporte para cerca de cinco studs dos blocos, cliques automatizados e pausas de instrumentação. Os tempos ativos não representam deslocamento manual, compreensão da UI, animações/interação humana ou uma sessão desde perfil novo (o perfil já tinha 86 moedas e BearGummy). São referência para rendimento do combate com dano 7,5.

## Dados finais e persistência

GetData após o GummyBlock e após Stop/Play devolveu o mesmo conteúdo lógico (ordem de chaves do dicionário ignorada):

```json
{
  "Version": 1,
  "Coins": 37,
  "Gems": 126,
  "Rebirths": 1,
  "UnlockedAreas": ["CandyPlaza"],
  "Inventory": {
    "4b35db1a-dcee-4654-8634-4deded4663cc": {"Id": "BearGummy"},
    "4d028dc5-f5f5-40d9-a321-945c43f2fb15": {"Id": "LollipopBunny"},
    "25808423-ec70-4b99-8d84-9d690a8347aa": {"Id": "CottonCat"},
    "1de6df16-35e2-40ac-8150-b1b37892da18": {"Id": "BearGummy"}
  },
  "Equipped": [
    "4b35db1a-dcee-4654-8634-4deded4663cc",
    "4d028dc5-f5f5-40d9-a321-945c43f2fb15",
    "25808423-ec70-4b99-8d84-9d690a8347aa"
  ],
  "Daily": {"LastClaimDay": 20772, "Streak": 1},
  "TutorialStep": 0,
  "Settings": {"Sfx": true, "Music": true},
  "CoinBoostUntil": 0,
  "Receipts": []
}
```

## Bugs

| Severidade | Achado | Arquivo/origem provável | Evidência e limite |
|---|---|---|---|
| Baixa, provisória | Asset com tipo incompatível repetido no carregamento | Origem não localizada; investigar avatar/conteúdo do place fora de `src/` | Seis ocorrências por sessão: `ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type`. Busca literal em `src/` e `assets/` não encontrou o ID; inspeção de Decal/Texture/Sound no Client também não encontrou. Sem stack trace, não é possível atribuir a um arquivo com segurança. Não impediu o ciclo ou salvamento |

Nenhum bug funcional foi observado no ciclo individual exercitado. Não houve ❌ nos passos executados.

## Não testado e verificação local

- Fusão: condição de cinco iguais desequipados ausente; não se compraram pets extras para forçar esse cenário.
- Dois a quatro jogadores simultâneos previstos no I1 do ROADMAP: esta execução foi individual; divisão de recompensas, concorrência entre jogadores e sessões de dados não foram revalidadas. **I1 multiplayer permanece pendente nesta execução.**
- Cliques/toques reais na UI, confirmação visual de hatch/rebirth, mobile, trajetos manuais, game passes, produtos e demais recursos da Fase 2. As operações foram disparadas pelos remotes no Client.
- Não foi feito novo teste de bloqueio de entrada após rebirth nem de portão fechado após reconexão; foi conferido o reset de UnlockedAreas.
- `lune run check` foi tentado e falhou antes de iniciar as etapas com `ERROR home directory not found`. Conforme a exceção documentada em docs/LICOES.md, o líder precisa executar o portão no ambiente dele. **Não se declara TUDO OK.**

## Como repetir no Studio

1. Na main sincronizada pelo Rojo, Play e GetData pelo Client; guardar snapshot e confirmar API disponível no Output.
2. Juntar moedas, aproximar-se do CandyEgg, comprar até três pets e equipar; registrar BlockHit.
3. Juntar 1.800 moedas, chamar UnlockArea para ChocolateFalls, inspecionar o Gate e permanecer na cascata por mais de um ciclo de fiscalização.
4. Juntar 2.500, comprar ChocolateEgg perto do ovo; só testar fusão quando houver os cinco pets exigidos.
5. Juntar o custo calculado para o Rebirths atual, registrar snapshot e chamar RequestRebirth; conferir resets, preservação e bônus em GummyBlock.
6. Stop, esperar pelo menos 12 s, Play, comparar todos os campos de GetData, verificar console e encerrar com Stop.

O perfil terminou com um rebirth: **o próximo rebirth custa 25.000 moedas** pela configuração atual. Repetir o roteiro altera dados reais e deve considerar esse estado.

## Complemento multiplayer (2 jogadores)

Executado em 15/11/2026, como complemento do I1 solicitado pela Squad B no PR #20. Local Server já aberto pelo humano, com main informada por ele. Checkout local do relatório: `a/mvp-fechado`; não se trocou branch nem conexão Rojo. Nenhum `src/` editado, commit, Kick, Stop ou fechamento de janela. Operações de jogo exclusivamente pelos Clients (`FireServer`, `InvokeServer`, `Character:PivotTo`); servidor consultado somente para leitura. Instrumentação temporária em `PlayerGui.MultiplayerTestEvidence`, sem alterar dados diretamente.

Instâncias identificadas por `list_roblox_studios` e `get_studio_state`: servidor `4b36a8f7-dd12-49cc-9745-2198952428e3`, Player1 `5bfda9a2-31a1-4c1e-8e48-4628d347a793`, Player2 `a2ff03f3-bfc6-477e-bb37-1ce675225e4d`. As três estavam em Play; foco Server/Client/Client respectivamente. Instância Edit separada preservada. Salvamento real confirmado pelo log do ProfileStore; não houve reconexão para comprovar persistência nesta rodada.

Snapshots iniciais de `GetData`:

| Campo | Player1 | Player2 |
|---|---|---|
| Coins / Gems / Rebirths | 35 / 0 / 0 | 25 / 0 / 0 |
| Inventory | `f359e03f-bf15-4909-a32f-abca458329a3: BearGummy` | vazio |
| Equipped | `[f359e03f-bf15-4909-a32f-abca458329a3]` | vazio |
| UnlockedAreas | `[CandyPlaza]` | `[CandyPlaza]` |
| TutorialStep | 5 | 0 |
| Daily | `{LastClaimDay=0, Streak=0}` | `{LastClaimDay=0, Streak=0}` |

| Passo | Resultado | Números e evidências |
|---|---|---|
| 1. Instâncias, dados e console inicial | ✅ | Servidor com exatamente Player1 e Player2 e **9 services**, confirmado pelo Output e número de módulos. API disponível para salvar. Cada console tinha duas ocorrências do asset conhecido `203785492`; nenhum erro novo de script observado. |
| 2. Divisão com danos diferentes | ✅ | LollipopBlock `25743ea6-5ad5-4948-bca0-552dfa5df065`, posição `(28,3,-24)`, HP 35, 22 moedas. Clientes posicionados a 5 studs (offsets `(0,0,5)` e `(3,0,4)`). Cliques alternados a aproximadamente 0,2 s: **Player1 9×3=27**, **Player2 8×1=8**; HP final 0. Coins **35→51 (+16)** e **25→30 (+5)**, exatamente `floor(22×27/35)=16` e `floor(22×8/35)=5`; soma **21≤22**. Notify REWARD e textos reais dos toasts: somente `+16 moedas` no Player1 e `+5 moedas` no Player2. O último golpe desta primeira quebra foi exato (3 HP). |
| 3. Pet visível no outro Client | ✅ | No Client de Player2, atributo de Player1 `EquippedPets="BearGummy"` e modelo `Workspace.ClientPets.Player1_Pet_1_BearGummy`. Antes: dono `(28,3,1075,-18,9998)`, pet aproximadamente `(28,2,7233,-14,7998)`, distância **4,2175** studs. Depois de mover Player1 para outro bloco: dono `(10,3,2075,-7)`, pet `(9,9942,2,7723,-2,8069)`, distância **4,2223**. Modelo acompanhou o dono no cliente observador. Coordenadas com vírgula decimal; vetores são aproximações. |
| 4. Compras simultâneas e sequência | ✅ | Após farm separado por 50 s: P1 **675**, P2 **358** moedas; inventários 1 e 0. Ambos perto de CandyEgg. Primeiros InvokeServer em `GetServerTimeNow` **1794777525,005824** e **1794777525,008877** (diferença **3,053 ms**); mais três pedidos seguidos por cliente, sem espera intencional, terminando os envios em 7525,106435/7525,108248. P1: **4 sucessos**, Coins **675→275**, Inventory **1→5**. P2: **3 sucessos + NOT_ENOUGH_COINS**, Coins **358→58**, Inventory **0→3**. Sete UUIDs novos distintos, todos presentes somente no inventário correto; pet antigo de P1 preservado. Pedido recusado não cobrou. |
| 5. Isolamento de equipagem e área | ✅ | EquipPet em P1 para `ba8669ca…` e `580c5af3…` retornou ok: equipados **1→3**. GetData de P2 manteve exatamente os três pets comprados, Equipped vazio, Coins 58, Gems/Rebirths 0, TutorialStep 3, Daily `{0,0}` e `[CandyPlaza]`. Após farm, P1 tinha **1.819** moedas; UnlockArea ChocolateFalls retornou ok, Coins **1.819→19** e áreas `[CandyPlaza,ChocolateFalls]`. No Client de P1, as cinco peças do Gate ficaram **Transparency=1, CanCollide=false**. P2 manteve `[CandyPlaza]`; Core continuou **0,25/true**, BarNorth, BarSouth, FrameTopBeam e CaramelStripeCenter **0/true**. P2 tinha então 63 moedas: os +5 anteriores vieram de REWARD em **1794777607,106207**, antes do desbloqueio, compatíveis com contribuição restante do farm em bloco terminado por P1. Nenhum crédito foi atribuído ao UnlockArea. |
| 6. Diária individual | ⚠️ | ClaimDaily de ambos retornou **`{ok=false,err="NOT_IMPLEMENTED"}`**. P1 permaneceu com 675 moedas, P2 com 358 (chamadas feitas antes das compras); Gems 0 e Daily `{0,0}` nos dois. Não foi possível validar crédito nem DAILY_NOT_READY nessa main em execução. |
| 7. Tutorial isolado | ✅ | Na quebra compartilhada, Player2 recebeu seu próprio REWARD de 5 e avançou **0→1**. Em seguida Player1 sozinho quebrou um GummyBlock próximo (Player1 **51→59**, +8); Player2 ficou com **30 moedas e TutorialStep 1**, sem avanço pela quebra alheia. Player1 ficou no passo 5. Só depois do farm próprio Player2 avançou para 2, e da compra própria para 3. |
| 8. Consoles finais e sessão | ⚠️ | Console relido nas três instâncias: **0 erros novos de script/DataStore**; permaneceram somente as **2 ocorrências por instância** do asset conhecido `rbxassetid://203785492` e os prints de diagnóstico antigos em P1. get_studio_state final confirmou **Play nas três**, foco Server/Client/Client. Não houve Stop, Kick ou fechamento. |

**Rodada adicional do passo 2, com overkill real:** LollipopBlock `5db441b6-8c5e-45b5-b883-38d6ee34a844`, `(38,3,10)`, HP 35. Agora P1 equipado com BearGummy + CottonCat + BearGummy: dano nominal medido **6,5**; P2 continuou com **1**. P2 iniciou, alternância de aproximadamente 0,2 s, cinco golpes cada. HP antes do último golpe: **4**; BlockHit mostrou damage 6,5 e HP 0. Dano efetivo P1 **4×6,5+4=30**, P2 **5×1=5**. Recompensas **floor(22×30/35)=18** e **floor(22×5/35)=3**, soma **21≤22**, em vez de contar os 2,5 de excesso. GetData **P1 19→37**, **P2 63→66**; Notify e toasts exclusivos **+18 moedas / +3 moedas**. Resultado: ✅.

Compras de Player1: CottonCat `ba8669ca-f776-4bad-b964-e26c90b149bd`, CottonCat `bcced3e7-1dbe-4e39-9044-09f6ed985627`, BearGummy `580c5af3-94aa-4963-8c6a-ab1daed266f5`, CottonCat `0d927915-fe60-4576-95e7-ba538dfc8a99`. Compras de Player2: BearGummy `73f41bd6-3e59-4c44-9eca-d50e0e844db1`, CottonCat `2e1e9a54-b438-49bb-8f28-8472161eef99`, CottonCat `fcde0d36-112f-46e6-bcdc-f42be8e46a7f`.

**Estado final:** Player1 Coins **37**, Gems **0**, Rebirths **0**, Inventory **5**, Equipped **3**, duas áreas e TutorialStep **5**; Player2 Coins **66**, Gems **0**, Rebirths **0**, Inventory **3**, Equipped **0**, somente CandyPlaza e TutorialStep **3**. Daily permaneceu `{LastClaimDay=0, Streak=0}` em ambos. Dados reais dos perfis de teste foram alterados pelas ações acima.

### Bugs

- Nenhum bug funcional observado nos fluxos multiplayer de combate, compra, equipagem, área e tutorial exercitados.
- **Diária indisponível no runtime testado:** dois retornos NOT_IMPLEMENTED, em vez de prêmio/DAILY_NOT_READY. O contrato prevê esse fallback para handler ausente; não se atribui a falha à implementação da A8 sem testar sua versão. Revalidar o passo 6 com DailyService integrado. A execução tinha 9 services e nenhum crédito diário.
- Asset incompatível `203785492`: mesmo achado já registrado no teste individual, sem novas ocorrências nos consoles durante este complemento.

### Não testado

- Resgate diário efetivo, DAILY_NOT_READY e isolamento de crédito diário, bloqueados pelo NOT_IMPLEMENTED.
- Persistência após saída/reentrada dos dois perfis: salvamento real habilitado, porém Play foi preservado conforme pedido.
- Distribuição de gemas entre contribuidores: LollipopBlock não pagou gemas; não houve teste de empate em bloco com gemas.
- Quarta compra bem-sucedida de P2: saldo insuficiente; foram exercitados os quatro pedidos, com três entregas e uma recusa sem cobrança. Sem teste de inventário cheio, retries idempotentes ou mais de dois clientes.
- Tutorial isolado observado no passo 1, além da preservação do passo 3 durante equipagens/farm alheios; não foi reiniciado perfil nem coberta toda combinação de passos.
- Cliques manuais, hatch visual, mobile e demais itens fora deste complemento.
- `lune run check` tentado nesta rodada: **ERROR home directory not found** antes das etapas. Conforme docs/LICOES.md, o líder deve executar o portão no ambiente dele; não se declara TUDO OK.

Para repetir no Studio: (1) humano abre Local Server com dois clientes na main e coleta GetData; (2) ambos a 5 studs de Lollipop inteiro, alternam cliques a 0,2 s e comparam dano efetivo/recompensas/toasts; (3) observador acompanha ClientPets antes/depois de mover o dono; (4) cada um com saldo ≥100, perto do CandyEgg, agenda primeiro pedido no mesmo GetServerTimeNow e mais três seguidos, comparando UUIDs e débitos; (5) equipa e compra área só em um, comparando GetData e as cinco peças do Gate nos dois; (6) chama ClaimDaily em cada um; (7) quebra sem contribuição do observador e compara TutorialStep; (8) relê os três consoles. Repetir altera os perfis reais de teste; encerramento permanece a cargo do humano.
