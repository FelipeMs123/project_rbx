# Roadmap

Status: ⬜ a fazer · 🟡 em andamento (com nome) · ✅ pronto (com PR)

## Fase 0: Fundação ✅

Toolchain (Rokit), Rojo, ProfileStore, `DataService`, `EconomyService` (moedas, gemas, `Spend`,
`HasArea`), `NetServer`/`NetClient`, `DataController`, contrato, configs iniciais,
`lune run check`, CI, documentação do time e agentes.

---

## Fase 1: MVP jogável

Cada squad tem 6 tarefas no mesmo formato: 1 de lógica pura, 2 de servidor, 2 de cliente e
1 no Studio. As duas começam juntas; ninguém depende do outro para começar (os stubs seguram).

### Squad A: Blocos e Mundo

**A1 🟡 Fórmulas dos blocos** (Felipe: código pronto, falta teste no Studio) (`rbx-logica`)
- Arquivos: `src/shared/Logic/Formulas.luau`, `tests/Formulas.spec.luau`.
- `damage(baseDamage, petBonus)` e `splitReward(coins, gems, maxHp, damageByPlayer)` com as regras
  do GDD (overkill não conta, gemas para quem deu mais dano, empate = último golpe).
- Pronto quando: testes cobrem 1 jogador, 3 jogadores, overkill, empate de gemas, `Gems = 0`.

**A2 🟡 BlockService** (Felipe: código pronto, falta teste no Studio) (`rbx-server`)
- Arquivo: `src/server/Services/BlockService.luau`.
- Nasce blocos nos `Workspace.Areas.*.BlockSpawns`. Sem mapa e no Studio: cria uma área de teste
  com 6 spawns perto da origem.
- Modelo de `ServerStorage.BlockTemplates.<tipo>` ou placeholder (Part 4x4x4 colorida).
- Atributos `BlockId`, `BlockType`, `HP`, `MaxHP`, `Area` no Model, dentro de `Workspace.Blocks`.
- `RequestClick(blockId)` com todas as validações do CONTRATO e rate limit 15/s.
- Dano = `Formulas.damage(BaseDamage, PetService.GetDamageBonus(player))`. Guarda o dano por
  jogador; ao quebrar, `splitReward` -> `EconomyService.AddCoins/AddGems`, `BlockBroken`, respawn.
- `BlockHit` / `BlockBroken` via `NetServer.FireNearby(..., EffectsRadius)`. Limpa quem sai.
- Pronto quando: com 2 players no Studio os dois quebram o mesmo bloco e as moedas batem com o GDD.

**A3 🟡 AreaService** (Felipe: código pronto, falta teste no Studio) (`rbx-server`)
- Arquivo: `src/server/Services/AreaService.luau`.
- Remote `UnlockArea(areaId)`: área existe, ainda não liberada, a anterior (`Order - 1`) liberada,
  `EconomyService.Spend`, depois adiciona em `UnlockedAreas`. Rate 2/s.
- Personagem que entra numa área bloqueada volta para a última liberada (checagem a cada ~1 s).
- Pronto quando: sem moedas devolve `NOT_ENOUGH_COINS`; pular área devolve `AREA_LOCKED`.

**A4 🟡 Cliente: blocos** (Felipe: código pronto, falta teste no Studio) (`rbx-client`)
- Arquivo: `src/client/Controllers/BlockController.luau`.
- Clique/toque no bloco -> `RequestClick` (só o pedido; nenhum número calculado no cliente).
- Barra de HP sobre o bloco (lê atributos), efeito ao `BlockHit` (balanço, partículas, número de
  dano) e ao `BlockBroken` (explosão de doce, som).

**A5 🟡 Cliente: HUD e portões** (Felipe: código pronto, falta teste no Studio) (`rbx-client`)
- Arquivos: `src/client/Controllers/HudController.luau`, `AreaController.luau`, `src/client/UI/Hud/`.
- HUD: moedas e gemas com números abreviados (1.2K, 3.4M), avisos de `Notify` e de `Result.err`
  em português. Funciona bem no celular.
- Portões: mostram o preço, botão comprar -> `UnlockArea`, somem quando a área é liberada.

**A6 ⬜ Studio: Praça dos Doces** (humano)
- `Workspace.Areas.CandyPlaza` (área inicial, spawn do jogador) com `BlockSpawns` e lugar do ovo.
- Modelos dos 4 blocos em `ServerStorage.BlockTemplates`. Salvar em `assets/`.

### Squad B: Pets e Progressão

**B1 ⬜ Lógica pura** (`rbx-logica`)
- Arquivos: `src/shared/Logic/Inventory.luau`, `WeightedRoll.luau`, `Rebirth.luau` + testes.
- `WeightedRoll.pick(weights, r)`: escolhe pelo peso com o número aleatório injetado
  (0 <= r < 1), em ordem determinística (chaves ordenadas).
- `Inventory.canAdd(data, max)`, `canEquip(data, uuid, maxEquipped)` -> (ok, errCode),
  `bonus(data, petsConfig)` -> soma dos multiplicadores equipados.
- `Rebirth.cost(rebirths, baseCost, growth)` (fórmula do GDD).
- Pronto quando: testes cobrem limites, UUID inexistente, já equipado, distribuição do sorteio.

**B2 ⬜ PetService** (`rbx-server`)
- Arquivo: `src/server/Services/PetService.luau`.
- `AddPet` (UUID com `HttpService:GenerateGUID(false)`, respeita `MaxInventory`),
  `GetDamageBonus`, remotes `EquipPet` / `UnequipPet` (validações do CONTRATO, rate 8/s).
- Atributo `EquippedPets` no Player sempre igual ao `Equipped` salvo.
- Ao carregar: remove de `Equipped` UUIDs que não existem mais e PetIds que sumiram do Config.
- Pronto quando: equipar o 4º pet devolve `MAX_EQUIPPED`; UUID de outro jogador devolve `NOT_OWNED`.

**B3 ⬜ EggService e RebirthService** (`rbx-server`; depois da B2)
- Arquivos: `src/server/Services/EggService.luau`, `RebirthService.luau`.
- `PurchaseEgg(eggId)`: ovo existe -> área liberada -> espaço no inventário -> `Spend` ->
  sorteio com `Random.new()` no servidor -> `AddPet`. Rate 4/s. Devolve `{ uuid, petId }`.
- `RequestRebirth()`: `Spend` do custo, `Rebirths += 1`, `Coins = StartingCoins`,
  `UnlockedAreas = { StartingArea }`, `+ RebirthGemReward` gemas. Pets ficam. Rate 2/s.
- Pronto quando: sem moedas recusa sem sortear; inventário cheio recusa sem cobrar; rebirth zera
  moedas e mantém pets.

**B4 ⬜ Cliente: pets e inventário** (`rbx-client`)
- Arquivos: `src/client/Controllers/PetController.luau`, `src/client/UI/Pets/`.
- Pets seguem **todos** os jogadores, lendo o atributo `EquippedPets` (modelo de
  `ReplicatedStorage.PetModels` ou placeholder). Movimento só no cliente, sem física.
- Inventário: grade de pets com raridade e multiplicador, equipar/desequipar, contador 3/3 e 50/50.

**B5 ⬜ Cliente: ovos e rebirth** (`rbx-client`)
- Arquivos: `src/client/Controllers/EggController.luau`, `RebirthController.luau`,
  `src/client/UI/Eggs/`, `src/client/UI/Rebirth/`.
- Ovo: chegar perto -> botão comprar -> animação de chocar -> mostra o pet.
- Rebirth: botão com custo e bônus atual/próximo, confirmação antes de zerar.

**B6 ⬜ Studio: Cascata de Chocolate** (humano)
- `Workspace.Areas.ChocolateFalls` com `BlockSpawns` e `Gate`.
- Modelos dos 5 pets em `ReplicatedStorage.PetModels` e dos 2 ovos nas áreas. Salvar em `assets/`.

### Integração (os dois)

**I1 ⬜ Playtest do MVP**: 2 a 4 players no Studio, ciclo completo (bater, comprar ovo, equipar,
dano maior, liberar área, rebirth), sair e voltar com dados salvos.

**I2 ⬜ Revisão de segurança geral** (`rbx-revisor`): todos os remotes contra a tabela do CONTRATO.

---

## Fase 2: ideias (não começar antes do MVP)

Game Passes e Developer Products, mais áreas, recompensa diária, ranking global, troca e
fusão de pets, sons e música, tutorial curto. (Studio MCP para os agentes mexerem no Studio: já em uso para testes via receita `docs/agentes/receitas/teste-studio.md`, acionado de propósito só pelo líder, um testador por vez, Studio conectado ao `rojo serve` do branch certo; agentes de código não abrem o Studio).
