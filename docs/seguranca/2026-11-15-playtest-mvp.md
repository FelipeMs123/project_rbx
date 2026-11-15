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
