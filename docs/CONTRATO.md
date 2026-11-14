# Contrato entre as squads

Este documento é a "interface" do jogo. Enquanto ele for respeitado, a Squad A e a Squad B
trabalham em paralelo sem quebrar uma à outra.

**Regra:** mudar qualquer coisa aqui exige PR aprovado pelas duas squads, atualizando este
arquivo e o código no mesmo PR. Adicionar é barato; renomear ou remover é caro.

Arquivos de contrato: `src/shared/Net/Remotes.luau`, `src/shared/Types.luau`,
`src/shared/ErrorCodes.luau`, `src/shared/Config/Game.luau`, `src/server/Data/Template.luau`,
`src/server/Net/NetServer.luau`, `src/server/Services/DataService.luau`, `src/client/Net/NetClient.luau`,
`src/client/Controllers/DataController.luau`, e a API pública de cada Service.

---

## 1. Dados salvos (`PlayerData`)

ProfileStore `PlayerData_v1`, chave `Player_<UserId>`.

| Campo | Tipo | Padrão | Dono |
|---|---|---|---|
| `Version` | number | 1 | fundação |
| `Coins` | number | 100 | A |
| `Gems` | number | 0 | A |
| `Rebirths` | number | 0 | A |
| `UnlockedAreas` | `{string}` | `{"CandyPlaza"}` | A |
| `Inventory` | `{[uuid]: {Id: string}}` | `{}` | B |
| `Equipped` | `{uuid}` | `{}` (máx. `MaxEquipped` = 3) | B |

Diferenças em relação ao prompt original, de propósito:
- `Inventory` é um dicionário por UUID, não uma lista: busca direta e sem UUID duplicado.
- O pet salva só `Id`. `Rarity` e `Multiplier` vêm de `Config/Pets` na hora. Rebalancear
  um pet vale para todo mundo sem migração. Variantes futuras (dourado, arco-íris) entram como
  campo novo `Variant`.
- Sem `JSONEncode`: o DataStore já serializa tabelas. Só tabelas, strings, números e booleanos.
- Inventário limitado a `MaxInventory` = 50 pets (protege o limite de 4 MB por chave).

Escrita só por `DataService.Set/Update`. Cada escrita atualiza `leaderstats` (Coins, Gems,
Rebirths) e manda `DataChanged(key, value)` ao dono dos dados.

## 2. Remotes (`ReplicatedStorage.Remotes`)

Criados pelo `NetServer.Init()`. Rate limit é por jogador e por remote.

### Cliente -> Servidor

| Remote | Tipo | Argumentos | Retorno | Rate limit | Dono |
|---|---|---|---|---|---|
| `GetData` | Function | - | `Result{data: PlayerData}` | 2/s | fundação |
| `RequestClick` | Event | `blockId: string` | - | 15/s, burst 15 | A |
| `RequestRebirth` | Function | - | `Result` | 2/s | A |
| `UnlockArea` | Function | `areaId: string` | `Result` | 2/s | A |
| `EquipPet` | Function | `uuid: string` | `Result` | 8/s | B |
| `UnequipPet` | Function | `uuid: string` | `Result` | 8/s | B |
| `PurchaseEgg` | Function | `eggId: string` | `Result{data: {uuid, petId}}` | 4/s | B |

Validações obrigatórias no servidor:
- `RequestClick`: `blockId` é string de até 64 caracteres; o bloco existe e está vivo;
  a área do bloco está liberada para o jogador; o personagem está vivo e a até
  `MaxHitDistance + HitDistanceTolerance` studs do bloco (posição do `HumanoidRootPart`
  no servidor).
- `EquipPet/UnequipPet`: `uuid` é string de até 64 caracteres e existe no `Inventory` do jogador.
- `PurchaseEgg`: ovo existe; área do ovo liberada; jogador perto do ovo no mapa (quando o
  mapa existir); espaço no inventário **antes** de cobrar; cobra, sorteia e entrega.
- `UnlockArea`: área existe, ainda não liberada, a anterior (`Order - 1`) já liberada, saldo.

### Servidor -> Cliente

| Remote | Tipo | Argumentos | Para quem |
|---|---|---|---|
| `DataChanged` | Event | `key: string, value: any` | dono dos dados |
| `BlockHit` | UnreliableEvent | `blockId, hp, maxHp, damage, attacker: Player` | jogadores a até `EffectsRadius` |
| `BlockBroken` | Event | `blockId, position: Vector3, blockType: string` | jogadores a até `EffectsRadius` |
| `Notify` | Event | `code: string, payload: any?` | um jogador (ex.: recompensa, erro) |

### Estado replicado por atributos (sem remote)

| Onde | Atributo | Tipo | Dono |
|---|---|---|---|
| Model do bloco (`Workspace.Blocks`) | `BlockId`, `BlockType`, `HP`, `MaxHP`, `Area` | string/number | A |
| `Player` | `EquippedPets` | string: PetIds separados por vírgula, ex. `"BearGummy,CottonCat"` | B |

Entrou depois no jogo? Atributos já chegam prontos, sem pedido extra.

## 3. API entre Services (servidor)

Um Service só chama outro por estas funções.

### DataService (fundação, pronto)
```luau
DataService.Get(player): PlayerData?          -- só leitura
DataService.WaitForData(player, timeout?): PlayerData?
DataService.IsLoaded(player): boolean
DataService.Set(player, key, value): boolean
DataService.Update(player, key, (old) -> new): any
DataService.Save(player)
DataService.Loaded: Signal<(Player, PlayerData)>
DataService.Changed: Signal<(Player, key, value)>
```

### EconomyService (Squad A, tarefa A2)
```luau
EconomyService.AddCoins(player, amount): number   -- aplica bônus de rebirth; devolve o creditado
EconomyService.AddGems(player, amount): number
EconomyService.Spend(player, "Coins" | "Gems", amount): boolean
EconomyService.HasArea(player, areaId): boolean
```

### PetService (Squad B, tarefa B2)
```luau
PetService.GetDamageBonus(player): number         -- soma dos multiplicadores equipados
PetService.AddPet(player, petId): (uuid?, errCode?)
```

Até a tarefa ficar pronta, cada Service tem um stub com a mesma assinatura (ver o arquivo).
`PetService.GetDamageBonus` devolve 0 e `EconomyService.HasArea` devolve true.

## 4. Pastas do mapa (Studio)

| Caminho | O que é | Dono |
|---|---|---|
| `Workspace.Areas.<AreaId>.BlockSpawns` | Parts invisíveis onde nascem blocos. Atributo opcional `BlockType`. | A |
| `Workspace.Areas.<AreaId>.Gate` | Portão que some quando a área é liberada (no cliente). | A |
| `Workspace.Areas.<AreaId>.Eggs.<EggId>` | Model do ovo para comprar (com `PrimaryPart`). | B |
| `Workspace.Blocks` | Criado pelo servidor; blocos vivos. | A |
| `ServerStorage.BlockTemplates.<BlockType>` | Model do bloco (com `PrimaryPart`). | A |
| `ReplicatedStorage.PetModels.<PetId>` | Model do pet (com `PrimaryPart`). | B |

Sem modelo no Studio, o código usa um placeholder (Part colorida) para tudo funcionar
em um place vazio.
