# Roadmap

Status: ⬜ a fazer · 🟡 em andamento (com nome) · ✅ pronto (com PR)

## Fase 0: Fundação ✅

Toolchain (Rokit), Rojo, ProfileStore, `DataService`, `NetServer`/`NetClient`, `DataController`,
contrato, configs iniciais, `lune run check`, CI, documentação do time e agentes.

---

## Fase 1: MVP jogável

Ordem sugerida em cada squad: de cima para baixo. As duas squads começam juntas.

### Squad A: economia e blocos

**A1 ⬜ Fórmulas puras** (`rbx-logica`)
- Arquivos: `src/shared/Logic/Formulas.luau`, `tests/Formulas.spec.luau`.
- Funções (puras, config por parâmetro): `damage(baseDamage, petBonus)`,
  `splitReward(coins, gems, maxHp, damageByPlayer)` (regras no GDD, inclusive overkill e gemas),
  `rebirthCost(rebirths, cfg)`, `coinMultiplier(rebirths, cfg)`.
- Pronto quando: testes cobrem 1 jogador, 3 jogadores, overkill, empate de gemas, `Gems = 0`.

**A2 ⬜ EconomyService** (`rbx-server`)
- Arquivo: `src/server/Services/EconomyService.luau`.
- `AddCoins` (com `coinMultiplier`), `AddGems`, `Spend` (recusa valor <= 0, NaN, infinito),
  `HasArea`. Remotes `RequestRebirth` e `UnlockArea` com as validações do CONTRATO e rate limit 2/s.
- Pronto quando: comprar área e fazer rebirth funcionam no Studio pela barra de comandos
  (`require(...)`); sem saldo devolve `NOT_ENOUGH_COINS`.

**A3 ⬜ BlockService** (`rbx-server`)
- Arquivo: `src/server/Services/BlockService.luau` (+ `Formulas` da A1).
- Nasce blocos nos `Workspace.Areas.*.BlockSpawns`. Se não existir mapa e estiver no Studio,
  cria uma área de teste com 6 spawns perto da origem.
- Modelo de `ServerStorage.BlockTemplates.<tipo>` ou placeholder (Part 4x4x4 colorida).
- Atributos `BlockId`, `BlockType`, `HP`, `MaxHP`, `Area` no Model, dentro de `Workspace.Blocks`.
- `RequestClick(blockId)` com todas as validações do CONTRATO e rate limit 15/s.
- Dano = `Formulas.damage(BaseDamage, PetService.GetDamageBonus(player))`. Guarda o dano por
  jogador; ao quebrar, `splitReward` -> `EconomyService.AddCoins/AddGems`, `BlockBroken`, respawn.
- `BlockHit` / `BlockBroken` via `NetServer.FireNearby(..., EffectsRadius)`.
- Limpa o dano registrado de quem sai do jogo.
- Pronto quando: com 2 players no Studio os dois quebram o mesmo bloco e as moedas batem com o GDD.

**A4 ⬜ Cliente: blocos e HUD** (`rbx-client`)
- Arquivos: `src/client/Controllers/BlockController.luau`, `HudController.luau`, `src/client/UI/Hud/`.
- Clique/toque no bloco -> `RequestClick` (só o pedido; nenhum número calculado no cliente).
- Barra de HP sobre o bloco (lê atributos), efeito ao `BlockHit` (balanço, partículas, número de
  dano) e ao `BlockBroken` (explosão de doce, som).
- HUD: moedas, gemas, rebirths com números abreviados (1.2K, 3.4M), botão de rebirth com custo,
  aviso de erro (`Notify` / `Result.err` em português). Funciona bem no celular.

**A5 ⬜ Studio: mapa** (humano)
- `Workspace.Areas.CandyPlaza` e `ChocolateFalls` com `BlockSpawns`, `Gate` e lugar para os ovos.
- Modelos dos 4 blocos em `ServerStorage.BlockTemplates`. Salvar em `assets/`.

### Squad B: pets e ovos

**B1 ⬜ Lógica pura** (`rbx-logica`)
- Arquivos: `src/shared/Logic/Inventory.luau`, `src/shared/Logic/WeightedRoll.luau` + testes.
- `WeightedRoll.pick(weights, randomNumber)`: escolhe pelo peso com o número aleatório injetado
  (0 <= r < 1). Ordem determinística (chaves ordenadas).
- `Inventory.canAdd(data, max)`, `canEquip(data, uuid, maxEquipped)` -> (ok, errCode),
  `bonus(data, petsConfig)` -> soma dos multiplicadores equipados.
- Pronto quando: testes cobrem limites, UUID inexistente, já equipado, distribuição do sorteio.

**B2 ⬜ PetService** (`rbx-server`)
- Arquivo: `src/server/Services/PetService.luau`.
- `AddPet` (UUID com `HttpService:GenerateGUID(false)`, respeita `MaxInventory`),
  `GetDamageBonus`, remotes `EquipPet` / `UnequipPet` (validações do CONTRATO, rate 8/s).
- Atributo `EquippedPets` no Player sempre igual ao `Equipped` salvo.
- Ao carregar: remove de `Equipped` UUIDs que não existem mais e PetIds que sumiram do Config.
- Pronto quando: equipar o 4º pet devolve `MAX_EQUIPPED`; UUID de outro jogador devolve `NOT_OWNED`.

**B3 ⬜ EggService** (`rbx-server`; depende de A2 e B2)
- Arquivo: `src/server/Services/EggService.luau`.
- `PurchaseEgg(eggId)`: ovo existe -> área liberada -> espaço no inventário -> `Spend` ->
  sorteio com `Random.new()` no servidor -> `AddPet`. Rate 4/s. Devolve `{ uuid, petId }`.
- Pronto quando: sem moedas recusa sem sortear; com inventário cheio recusa sem cobrar.

**B4 ⬜ Cliente: pets e ovos** (`rbx-client`)
- Arquivos: `src/client/Controllers/PetController.luau`, `EggController.luau`, `src/client/UI/Pets/`, `src/client/UI/Eggs/`.
- Pets seguem **todos** os jogadores, lendo o atributo `EquippedPets` (modelo de
  `ReplicatedStorage.PetModels` ou placeholder). Movimento só no cliente, sem física.
- Inventário: grade de pets com raridade e multiplicador, equipar/desequipar, contador 3/3 e 50/50.
- Ovo: chegar perto -> botão comprar -> animação de chocar -> mostra o pet.

**B5 ⬜ Studio: modelos** (humano)
- Modelos dos 5 pets em `ReplicatedStorage.PetModels` e dos ovos no mapa. Salvar em `assets/`.

### Integração (os dois)

**I1 ⬜ Playtest do MVP**: 2 a 4 players no Studio, ciclo completo (bater, comprar ovo, equipar,
dano maior, liberar área, rebirth), sair e voltar com dados salvos.

**I2 ⬜ Revisão de segurança geral** (`rbx-revisor`): todos os remotes contra a tabela do CONTRATO.

---

## Fase 2: ideias (não começar antes do MVP)

Game Passes e Developer Products, mais áreas, recompensa diária, ranking global, troca e
fusão de pets, sons e música, tutorial curto, Studio MCP para os agentes mexerem no Studio.
