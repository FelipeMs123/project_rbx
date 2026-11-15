# Contrato entre as squads

Este documento é a "interface" do jogo. Enquanto ele for respeitado, a Squad A e a Squad B
trabalham em paralelo sem quebrar uma à outra.

**Regra:** mudar qualquer coisa aqui exige PR aprovado pelas duas squads, atualizando este
arquivo e o código no mesmo PR. Adicionar é barato; renomear ou remover é caro.

Arquivos de contrato: `src/shared/Net/Remotes.luau`, `src/shared/Types.luau`,
`src/shared/ErrorCodes.luau`, `src/shared/Config/Game.luau`, `src/server/Data/Template.luau`,
`src/server/Net/NetServer.luau`, `src/server/Services/DataService.luau`, `src/server/Services/EconomyService.luau`, `src/shared/Logic/Economy.luau`, `src/client/Net/NetClient.luau`,
`src/client/Controllers/DataController.luau`, e a API pública de cada Service.

---

## 1. Dados salvos (`PlayerData`)

ProfileStore `PlayerData_v1`, chave `Player_<UserId>`.

| Campo | Tipo | Padrão | Dono |
|---|---|---|---|
| `Version` | number | 1 | fundação |
| `Coins` | number | 25 (`StartingCoins`) | fundação (via EconomyService) |
| `Gems` | number | 0 | fundação (via EconomyService) |
| `Rebirths` | number | 0 | B |
| `UnlockedAreas` | `{string}` | `{"CandyPlaza"}` | A |
| `Inventory` | `{[uuid]: {Id: string, Variant: string?}}` | `{}` (`Variant` = `"Golden"` na v2) | B |
| `Equipped` | `{uuid}` | `{}` (máx. `MaxEquipped` = 3, ou 4 com o passe `ExtraPetSlot`) | B |
| `Daily` | `{LastClaimDay: number, Streak: number}` | `{LastClaimDay = 0, Streak = 0}` | A (v2) |
| `TutorialStep` | number | 0 (0 = não começou; `#Config.Tutorial` = concluído) | A (v2) |
| `Settings` | `{Music: boolean, Sfx: boolean}` | `{Music = true, Sfx = true}` | A (v2) |
| `CoinBoostUntil` | number (`os.time()` UTC) | 0 | B (v2) |
| `Receipts` | `{string}` (últimos 100 `PurchaseId`) | `{}` | B (v2) |

Diferenças em relação ao prompt original, de propósito:
- `Inventory` é um dicionário por UUID, não uma lista: busca direta e sem UUID duplicado.
- O pet salva `Id` e, na v2, `Variant` opcional (`"Golden"`). `Rarity` e `Multiplier` vêm de `Config/Pets` na hora. Rebalancear
  um pet vale para todo mundo sem migração. Variantes futuras (dourado, arco-íris) entram como
  campo novo `Variant`.
- Sem `JSONEncode`: o DataStore já serializa tabelas. Só tabelas, strings, números e booleanos.
- Inventário limitado a `MaxInventory` = 50 pets (protege o limite de 4 MB por chave).

Campos v2 entram pelo `Reconcile` do ProfileStore (jogador antigo ganha o padrão); `DataVersion` não muda.
`LastClaimDay` é o dia UTC: `math.floor(os.time() / 86400)`, sempre calculado no servidor.

Escrita só por `DataService.Set/Update`. Cada escrita atualiza `leaderstats` (Coins, Gems,
Rebirths) e manda `DataChanged(key, value)` ao dono dos dados.

## 2. Remotes (`ReplicatedStorage.Remotes`)

Criados pelo `NetServer.Init()`. Rate limit é por jogador e por remote. Remote ainda sem handler responde `NOT_IMPLEMENTED` com o limite padrão (v2).

### Cliente -> Servidor

| Remote | Tipo | Argumentos | Retorno | Rate limit | Dono |
|---|---|---|---|---|---|
| `GetData` | Function | - | `Result{data: PlayerData}` | 2/s | fundação |
| `RequestClick` | Event | `blockId: string` | - | 15/s, burst 15 | A |
| `RequestRebirth` | Function | `requestId: string?` (opcional, retrocompatível) | `Result` | 2/s | B |
| `UnlockArea` | Function | `areaId: string` | `Result` | 2/s | A |
| `EquipPet` | Function | `uuid: string` | `Result` | 8/s | B |
| `UnequipPet` | Function | `uuid: string` | `Result` | 8/s | B |
| `PurchaseEgg` | Function | `eggId: string, requestId: string?` (`requestId` opcional, retrocompatível) | `Result{data: {uuid, petId}}` | 4/s | B |
| `ClaimDaily` | Function | - | `Result{data: {day, streak, coins, gems}}` | 2/s | A (v2) |
| `SetTutorialStep` | Function | `step: number` | `Result` | 2/s | A (v2) |
| `SetSetting` | Function | `key: string, value: boolean` | `Result` | 2/s | A (v2) |
| `FusePets` | Function | `uuids: {string}` | `Result{data: {uuid, petId, variant}}` | 2/s | B (v2) |

Validações obrigatórias no servidor:
- `RequestClick`: `blockId` é string de até 64 caracteres; o bloco existe e está vivo;
  a área do bloco está liberada para o jogador; o personagem está vivo e a até
  `MaxHitDistance + HitDistanceTolerance` studs do bloco (posição do `HumanoidRootPart`
  no servidor).
- `EquipPet/UnequipPet`: `uuid` é string de até 64 caracteres e existe no `Inventory` do jogador.
- `PurchaseEgg`: ovo existe; área do ovo liberada; jogador perto do ovo no mapa (quando o
  mapa existir); espaço no inventário **antes** de cobrar; cobra, sorteia e entrega. `requestId` opcional
  (string de 1 a 64 chars) garante idempotência por jogador para retry após timeout do cliente (trava `inFlight` + cache FIFO limitado dos últimos 100 resultados).
- `RequestRebirth`: saldo >= custo; cobra, incrementa `Rebirths` (estornando `cost` diretamente se falhar), reseta moedas/áreas e credita gemas. `requestId` opcional (string de 1 a 64 chars) segue a mesma política de idempotência para retry após timeout do cliente.
- `UnlockArea`: área existe, ainda não liberada, a anterior (`Order - 1`) já liberada, saldo.
- `ClaimDaily` (v2): dia UTC do servidor maior que `Daily.LastClaimDay`, senão `DAILY_NOT_READY`.
  Sequência pelas regras de `Config/DailyRewards` (`Streak` conta 1..7 e volta a 1 depois do 7).
  **Grava `Daily` antes de creditar** (dois pedidos simultâneos não pagam duas vezes). Moedas por
  `EconomyService.AddCoins`, que já aplica rebirth e boosts: não multiplicar de novo. Gemas fixas
  por `AddGems`. `data.coins` devolve o valor creditado (retorno do `AddCoins`).
- `SetTutorialStep` (v2): `typeof(step) == "number"`, inteiro, finito, `TutorialStep < step <= #Config.Tutorial` (só aumenta).
- `SetSetting` (v2): `key` em `{"Music", "Sfx"}`, `value` boolean.
- `FusePets` (v2): array estrito (chaves só `1..RequiredCount`, conferido com `pairs`) de
  `Fusion.RequiredCount` UUIDs distintos (strings de 1 a 64), todos no inventário do jogador, mesmo
  `Id` existente em `Config/Pets`, sem `Variant`, nenhum equipado; senão `FUSE_INVALID`. Tudo
  validado **antes** de cobrar. Depois `Spend` das gemas da raridade (falhou: `NOT_ENOUGH_GEMS`) e,
  sem yield entre os passos, remove os pets e adiciona o dourado num único `DataService.Update`.

### Servidor -> Cliente

| Remote | Tipo | Argumentos | Para quem |
|---|---|---|---|
| `DataChanged` | Event | `key: string, value: any` | dono dos dados |
| `BlockHit` | UnreliableEvent | `blockId, hp, maxHp, damage, attacker: Player` | jogadores a até `EffectsRadius` |
| `BlockBroken` | Event | `blockId, position: Vector3, blockType: string` | jogadores a até `EffectsRadius` |
| `Notify` | Event | `code: string, payload: any?` | um jogador. `code` é um `ErrorCodes` ou `REWARD` com `payload = { coins, gems }` (já creditados). `AREA_NOT_UNLOCKED` vem com `payload = { areaId }` (v2) |

### Estado replicado por atributos (sem remote)

| Onde | Atributo | Tipo | Dono |
|---|---|---|---|
| Model do bloco (`Workspace.Blocks`) | `BlockId`, `BlockType`, `HP`, `MaxHP`, `Area` | string/number | A |
| `Player` | `EquippedPets` | string: PetIds separados por vírgula, com `:Variant` opcional (v2), ex. `"BearGummy:Golden,CottonCat"`. Quem lê ignora variante desconhecida e não corta a lista em 3 (o limite vem do servidor) | B |
| `Player` | `Passes` (v2) | string: chaves de Game Pass ativas separadas por vírgula, ex. `"AutoClicker,ExtraPetSlot"`. Escrito só pelo `MonetizationService` (no carregamento e após compra) | B |

Entrou depois no jogo? Atributos já chegam prontos, sem pedido extra.

## 3. API entre Services (servidor)

Um Service só chama outro por estas funções.

### DataService (fundação, pronto)
```luau
DataService.SaveAndWait(player, timeout?, isSaved?): boolean  -- v2: pede o save e espera um OnAfterSave cujo snapshot satisfaz isSaved (faz yield)
DataService.IsSaved(player, isSaved): boolean  -- v2: confere LastSavedData sem yield
DataService.Get(player): PlayerData?          -- só leitura
DataService.WaitForData(player, timeout?): PlayerData?
DataService.IsLoaded(player): boolean
DataService.Set(player, key, value): boolean
DataService.Update(player, key, (old) -> new): any
DataService.Save(player)
DataService.Loaded: Signal<(Player, PlayerData)>
DataService.Changed: Signal<(Player, key, value)>
```

### EconomyService (fundação, pronto)
```luau
EconomyService.AddCoins(player, amount): number   -- aplica bônus de rebirth; devolve o creditado
EconomyService.AddGems(player, amount): number
EconomyService.Spend(player, "Coins" | "Gems", amount): boolean  -- recusa NaN, negativo, infinito
EconomyService.GetBalance(player, "Coins" | "Gems"): number
EconomyService.HasArea(player, areaId): boolean
```

### AreaService (Squad A, tarefa A3) e RebirthService (Squad B, tarefa B3)
Só registram os remotes `UnlockArea` e `RequestRebirth`; não têm API para outros Services.
`AreaService` é o único que adiciona áreas em `UnlockedAreas`; o rebirth só volta para a área inicial.

### PetService (Squad B, tarefa B2)
```luau
PetService.GetDamageBonus(player): number         -- soma dos multiplicadores equipados
PetService.AddPet(player, petId): (uuid?, errCode?)
```

### MonetizationService (Squad B, tarefa B8; v2)
```luau
MonetizationService.HasPass(player, passKey: string): boolean   -- chaves de Config/Monetization.GamePasses
```
`HasPass` **não pode fazer yield**: lê um cache preenchido no carregamento do jogador
(`UserOwnsGamePassAsync`) e atualizado em `PromptGamePassPurchaseFinished`. O mesmo vale para os
multiplicadores registrados no `EconomyService`. Stub: `HasPass` = false.

Fluxo do `ProcessReceipt` (Developer Products), nesta ordem:
1. `ProductId` precisa existir em `Config/Monetization.DevProducts` com `Id > 0`; senão `NotProcessedYet` e log.
2. Jogador fora do servidor ou dados não carregados (`DataService.WaitForData` com timeout): `NotProcessedYet` (o Roblox tenta de novo).
3. `PurchaseId` já **salvo** (`DataService.IsSaved` conferindo `LastSavedData.Receipts`): devolve
   `PurchaseGranted` sem entregar de novo. Já em `Data.Receipts` mas ainda não salvo (tentativa
   anterior deu timeout): não entrega de novo, pula para o passo 5.
4. Sem yield entre as chamadas: entrega (gemas por `EconomyService.AddGems`, boost somando em
   `CoinBoostUntil` por `DataService.Update`) e grava o `PurchaseId` em `Receipts` (mantém os últimos 100).
   O servidor Luau roda uma coisa por vez: chamadas seguidas sem yield não se misturam com outro
   código, e as duas mudanças vão no mesmo `Profile.Data`, salvas juntas.
5. `DataService.SaveAndWait(player, timeout, isSaved)` com `isSaved` conferindo o `PurchaseId` em
   `LastSavedData.Receipts` (um auto-save que começou antes da compra não conta). `true`: devolve
   `PurchaseGranted`. `false`: devolve `NotProcessedYet` (o Roblox reentrega; o passo 3 evita
   entregar duas vezes). Erro em qualquer passo: `Notify("PURCHASE_FAILED")` e `NotProcessedYet`.

Por que 100 recibos bastam: o Roblox só reentrega o recibo que ainda não recebeu `PurchaseGranted`.
Um recibo concedido nunca volta; a lista só precisa cobrir os que estão em trânsito (é o padrão do
autor do ProfileStore, `docs/devproducts` do pacote). **Premissa:** no máximo 100 compras do mesmo
jogador pendentes de confirmação ao mesmo tempo. Acima disso, um recibo antigo sairia da lista e
poderia ser entregue de novo; para este jogo (compras manuais, uma por vez) o risco é desprezível.

Quem usa os passes:
- `ExtraPetSlot`: `PetService` (limite de equipados = `MaxEquipped + 1`); a UI de pets (B) lê o atributo `Passes`.
- `DoubleCoins` e boost: multiplicadores registrados pelo `MonetizationService` no `EconomyService`.
- `AutoClicker`: **Squad A**, no `BlockController` (que já tem o segurar-para-bater): com o passe no
  atributo `Passes`, bate sozinho a `ClicksPerSecond` (8/s, abaixo do rate limit de 15/s). O servidor
  não confia no passe para nada: o rate limit vale igual.

### EconomyService: multiplicadores de moedas (v2)
```luau
EconomyService.RegisterCoinMultiplier(name: string, fn: (Player) -> number)
```
`AddCoins` passa a creditar `floor(moedas * (1 + Rebirths * RebirthCoinBonus) * produto dos multiplicadores)`.
Cada multiplicador é chamado em `pcall`; valor inválido (NaN, infinito, < 1) conta como 1.
O `MonetizationService` registra `DoubleCoins` e `CoinBoostUntil` no `Init`; ninguém chama o `EconomyService` de volta.

Até a tarefa ficar pronta, cada Service tem um stub com a mesma assinatura (ver o arquivo).
`PetService.GetDamageBonus` devolve 0.

## 4. Config nova (v2)

| Arquivo | Dono | Origem dos números |
|---|---|---|
| `Config/DailyRewards.luau` | A | `docs/balanceamento/2026-11-15-fase2.md` |
| `Config/Tutorial.luau` | A | idem |
| `Config/Sounds.luau` | A | idem (IDs de asset preenchidos na A9) |
| `Config/Fusion.luau` | B | idem |
| `Config/Monetization.luau` | B | idem (IDs reais do Creator Hub na B8) |
| `Config/Leaderboard.luau` | B | idem |

## 5. Pastas do mapa (Studio)

| Caminho | O que é | Dono |
|---|---|---|
| `Workspace.Areas.<AreaId>.BlockSpawns` | Parts invisíveis onde nascem blocos. Atributo opcional `BlockType`. | quem constrói a área (CandyPlaza = A, ChocolateFalls = B) |
| `Workspace.Areas.<AreaId>.Gate` | Portão que some quando a área é liberada (lógica no cliente: A). | quem constrói a área |
| `Workspace.Areas.<AreaId>.Bounds` | Part opcional invisível, sem rotação e com CanCollide false, define a caixa da área. Sem ela, usa a AABB das Parts da pasta, exceto Gate e descendentes, com +50 studs no topo. | quem constrói a área |
| `Workspace.Areas.<AreaId>.SpawnLocation` | SpawnLocation opcional, filho direto da pasta. O `AreaService` devolve para cá quem entra numa área bloqueada depois desta; sem ela, usa o da CandyPlaza. | quem constrói a área |
| `Workspace.Areas.<AreaId>.Eggs.<EggId>` | Model do ovo para comprar (com `PrimaryPart`). | B |
| `Workspace.Blocks` | Criado pelo servidor; blocos vivos. | A |
| `ServerStorage.BlockTemplates.<BlockType>` | Model do bloco (com `PrimaryPart`). | A |
| `ReplicatedStorage.PetModels.<PetId>` | Model do pet (com `PrimaryPart`). | B |

Sem modelo no Studio, o código usa um placeholder (Part colorida) para tudo funcionar
em um place vazio.
