# Roadmap

Status: ⬜ a fazer · 🟡 em andamento (com nome) · ✅ pronto (com PR)

## Fase 0: Fundação ✅

Toolchain (Rokit), Rojo, ProfileStore, `DataService`, `EconomyService` (moedas, gemas, `Spend`,
`HasArea`), `NetServer`/`NetClient`, `DataController`, contrato, configs iniciais,
`lune run check`, CI, documentação do time e agentes.

---

## Fase 1: MVP jogável ✅ (fechado em 15/11/2026)

Cada squad tem 6 tarefas no mesmo formato: 1 de lógica pura, 2 de servidor, 2 de cliente e
1 no Studio. As duas começam juntas; ninguém depende do outro para começar (os stubs seguram).

### Squad A: Blocos e Mundo

**A1 ✅ Fórmulas dos blocos** (#7) (`rbx-logica`)
- Arquivos: `src/shared/Logic/Formulas.luau`, `tests/Formulas.spec.luau`.
- `damage(baseDamage, petBonus)` e `splitReward(coins, gems, maxHp, damageByPlayer)` com as regras
  do GDD (overkill não conta, gemas para quem deu mais dano, empate = último golpe).
- Pronto quando: testes cobrem 1 jogador, 3 jogadores, overkill, empate de gemas, `Gems = 0`.

**A2 ✅ BlockService** (#7) (`rbx-server`)
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

**A3 ✅ AreaService** (#7) (`rbx-server`)
- Arquivo: `src/server/Services/AreaService.luau`.
- Remote `UnlockArea(areaId)`: área existe, ainda não liberada, a anterior (`Order - 1`) liberada,
  `EconomyService.Spend`, depois adiciona em `UnlockedAreas`. Rate 2/s.
- Personagem que entra numa área bloqueada volta para a última liberada (checagem a cada ~1 s).
- Pronto quando: sem moedas devolve `NOT_ENOUGH_COINS`; pular área devolve `AREA_LOCKED`.

**A4 ✅ Cliente: blocos** (#7) (`rbx-client`)
- Arquivo: `src/client/Controllers/BlockController.luau`.
- Clique/toque no bloco -> `RequestClick` (só o pedido; nenhum número calculado no cliente).
- Barra de HP sobre o bloco (lê atributos), efeito ao `BlockHit` (balanço, partículas, número de
  dano) e ao `BlockBroken` (explosão de doce, som).

**A5 ✅ Cliente: HUD e portões** (#7) (`rbx-client`)
- Arquivos: `src/client/Controllers/HudController.luau`, `AreaController.luau`, `src/client/UI/Hud/`.
- HUD: moedas e gemas com números abreviados (1.2K, 3.4M), avisos de `Notify` e de `Result.err`
  em português. Funciona bem no celular.
- Portões: mostram o preço, botão comprar -> `UnlockArea`, somem quando a área é liberada.

**A6 ✅ Studio: Praça dos Doces** (#7, mapa gerado por código em `tools/map/`)
- `Workspace.Areas.CandyPlaza` (área inicial, spawn do jogador) com `BlockSpawns` e lugar do ovo.
- Modelos dos 4 blocos em `ServerStorage.BlockTemplates`. Salvar em `assets/`.

### Squad B: Pets e Progressão

**B1 ✅ Lógica pura** (#8) (`rbx-logica`)
- Arquivos: `src/shared/Logic/Inventory.luau`, `WeightedRoll.luau`, `Rebirth.luau` + testes.
- `WeightedRoll.pick(weights, r)`: escolhe pelo peso com o número aleatório injetado
  (0 <= r < 1), em ordem determinística (chaves ordenadas).
- `Inventory.canAdd(data, max)`, `canEquip(data, uuid, maxEquipped)` -> (ok, errCode),
  `bonus(data, petsConfig)` -> soma dos multiplicadores equipados.
- `Rebirth.cost(rebirths, baseCost, growth)` (fórmula do GDD).
- Pronto quando: testes cobrem limites, UUID inexistente, já equipado, distribuição do sorteio.

**B2 ✅ PetService** (#12) (`rbx-server`)
- Arquivo: `src/server/Services/PetService.luau`.
- `AddPet` (UUID com `HttpService:GenerateGUID(false)`, respeita `MaxInventory`),
  `GetDamageBonus`, remotes `EquipPet` / `UnequipPet` (validações do CONTRATO, rate 8/s).
- Atributo `EquippedPets` no Player sempre igual ao `Equipped` salvo.
- Ao carregar: remove de `Equipped` UUIDs que não existem mais e PetIds que sumiram do Config.
- Pronto quando: equipar o 4º pet devolve `MAX_EQUIPPED`; UUID de outro jogador devolve `NOT_OWNED`.

**B3 ✅ EggService e RebirthService** (#14) (`rbx-server`; depois da B2)
- Arquivos: `src/server/Services/EggService.luau`, `RebirthService.luau`.
- `PurchaseEgg(eggId)`: ovo existe -> área liberada -> espaço no inventário -> `Spend` ->
  sorteio com `Random.new()` no servidor -> `AddPet`. Rate 4/s. Devolve `{ uuid, petId }`.
- `RequestRebirth()`: `Spend` do custo, `Rebirths += 1`, `Coins = StartingCoins`,
  `UnlockedAreas = { StartingArea }`, `+ RebirthGemReward` gemas. Pets ficam. Rate 2/s.
- Pronto quando: sem moedas recusa sem sortear; inventário cheio recusa sem cobrar; rebirth zera
  moedas e mantém pets.

**B4 ✅ Cliente: pets e inventário** (#9) (`rbx-client`)
- Arquivos: `src/client/Controllers/PetController.luau`, `src/client/UI/Pets/`.
- Pets seguem **todos** os jogadores, lendo o atributo `EquippedPets` (modelo de
  `ReplicatedStorage.PetModels` ou placeholder). Movimento só no cliente, sem física.
- Inventário: grade de pets com raridade e multiplicador, equipar/desequipar, contador 3/3 e 50/50.

**B5 ✅ Cliente: ovos e rebirth** (#15) (`rbx-client`)
- Arquivos: `src/client/Controllers/EggController.luau`, `RebirthController.luau`,
  `src/client/UI/Eggs/`, `src/client/UI/Rebirth/`.
- Ovo: chegar perto -> botão comprar -> animação de chocar -> mostra o pet.
- Rebirth: botão com custo e bônus atual/próximo, confirmação antes de zerar.

**B6 ✅ Studio: Cascata de Chocolate** (#13) (humano)
- `Workspace.Areas.ChocolateFalls` com `BlockSpawns` e `Gate`.
- Modelos dos 5 pets em `ReplicatedStorage.PetModels` e dos 2 ovos nas áreas. Salvar em `assets/`.

### Integração (os dois)

**I1 ✅ Playtest do MVP** (`docs/seguranca/2026-11-15-playtest-mvp.md`; 2 jogadores na A-P2): 2 a 4 players no Studio, ciclo completo (bater, comprar ovo, equipar,
dano maior, liberar área, rebirth), sair e voltar com dados salvos.

**I2 ✅ Revisão de segurança geral** (#19, `docs/seguranca/2026-11-15-revisao-mvp.md`) (`rbx-revisor`): todos os remotes contra a tabela do CONTRATO.

---

## Fase 1.5: fechar o MVP (Squad A, enquanto a Squad B termina B2, B3, B5 e B6)

**A-P1 ✅ Aviso certo ao ser expulso de área** (`rbx-server` + `rbx-client`; entra no PR do contrato v2)
- `AreaService` manda `Notify("AREA_NOT_UNLOCKED", { areaId })`; o HUD mostra
  "Compre <nome da área> no portão para entrar." (hoje mostra "Libere a área anterior primeiro.").

**A-P2 ✅ Teste com 2 jogadores** (humano; o MCP do Studio não abre 2 clientes)
- Studio > Test > Clients and Servers, 2 players, os dois batem no mesmo bloco.
- Pronto quando: moedas divididas pelo dano (GDD), gemas para quem deu mais dano, nenhum erro no Output.

**A-P3 ✅ Salvamento real** (humano publica; agente testa)
- Publicar o place, ligar Game Settings > Security > Enable Studio Access to API Services.
- Pronto quando: sair e voltar mantém moedas, gemas, áreas e pets; o aviso do ProfileStore some.

**A-P4 ✅ Teste no emulador de celular** (humano)
- Studio > Test > Device (celular deitado e em pé): HUD, botão Pets, toque no bloco, portões.

O MVP fecha com I1 e I2 (acima), depois que a Squad B entregar B2, B3, B5 e B6.

---

## Fase 2: conteúdo e monetização

Começa com **o contrato v2** (um PR, aprovado pelas duas squads, como na Fase 0): todos os
campos de dados, remotes, códigos de erro e stubs da Fase 2 entram de uma vez, com valor padrão.
Depois cada squad trabalha só no que é dela, sem esperar a outra. Números e textos vêm de
`docs/balanceamento/2026-11-15-fase2.md` (rbx-design) e vão para `src/shared/Config/`.

**C2 ✅ Contrato v2** (#11) (líder da Squad A escreve; as duas squads aprovam)
- Dados: `Daily`, `TutorialStep`, `Settings` (A); `Variant` opcional no pet, `CoinBoostUntil`, `Receipts` (B).
- Atributos do `Player`: `EquippedPets` aceita `:Variant`; `Passes` novo (B).
- Remotes: `ClaimDaily`, `SetTutorialStep`, `SetSetting` (A); `FusePets` (B).
- Códigos de erro: `AREA_NOT_UNLOCKED`, `DAILY_NOT_READY`, `FUSE_INVALID`, `PURCHASE_FAILED`.
- `MonetizationService` (B) com stub `HasPass(player, passKey)` = false; multiplicadores de moedas
  entram por `EconomyService.RegisterCoinMultiplier` (sem yield). Fluxo do `ProcessReceipt` no contrato.
- Inclui a A-P1.

### Squad A: Mundo e Experiência

**A7 ⬜ Área 3: Nuvens de Algodão** (`rbx-design` + Studio por código, como a A6)
- `Workspace.Areas.CottonClouds` com `BlockSpawns`, `Gate`, `Bounds`, `SpawnLocation`, gerado em `tools/map/`.
- Pronto quando: comprar a área no portão libera; quem não tem é devolvido; CloudBlock nasce lá.

**A8 🟡 Recompensa diária** (#16) (`rbx-logica` + `rbx-server` + `rbx-client`)
- `Logic/Daily.luau` puro (dia UTC, sequência, valor do dia) com testes; `DailyService` (`ClaimDaily`);
  tela com os 7 dias e o botão de resgatar.
- Pronto quando: resgata 1 vez por dia; sequência segue as regras do balanceamento; mudar o
  relógio do cliente não muda nada (o servidor decide o dia).

**A9 ⬜ Sons e música** (`rbx-client`)
- `SoundController`: sons dos eventos (clique, quebra, moedas, gemas, área liberada, erro) e uma
  música por área; liga/desliga em `Settings` (`SetSetting`). IDs em `Config/Sounds.luau`.

O passe **AutoClicker** é da Squad A (no `BlockController`, lendo o atributo `Passes`): entra na A8 ou numa tarefa pequena depois da B8.

**A10 🟡 Tutorial curto** (#18) (`rbx-client` + `rbx-server`)
- 4 a 6 passos (quebrar bloco, juntar moedas, comprar ovo, equipar); seta e texto grandes;
  `SetTutorialStep` só aumenta; pula para quem já jogou.

### Squad B: Pets e Progressão

**B7 ✅ Fusão de pets** (#17) (`rbx-logica` + `rbx-server` + `rbx-client`)
- N pets iguais viram 1 dourado (`Variant = "Golden"`), multiplicador maior. `FusePets(uuids)`
  valida dono, quantidade, mesmo `Id`, não equipados; remove antes de entregar.

**B8 ⬜ Game Passes e Developer Products** (`rbx-server` + `rbx-client`)
- `MonetizationService`: cache de passes + atributo `Passes`, multiplicadores (2x moedas, boost) e
  produtos (gemas, boost 2x por tempo). A UI de pets passa a ler o limite do atributo `Passes` e o
  `PetController` deixa de cortar `EquippedPets` em 3 e entende `:Golden`.
- `ProcessReceipt` idempotente: grava o `PurchaseId` em `Receipts` antes de confirmar.
- Nada de ovo só por Robux sem mostrar as chances.

**B9 ⬜ Ranking global** (`rbx-server` + Studio)
- OrderedDataStore da estatística definida no balanceamento; placar (SurfaceGui) na praça,
  atualizado pelo servidor dentro dos limites do DataStore. Sem remote novo.

### Integração da Fase 2

**I3 ⬜ Playtest da Fase 2** e **I4 ⬜ Revisão de segurança** dos remotes novos e do `ProcessReceipt`.

## Fase 3: Arte e Conte?do (antes do lan?amento)

Meta: aproximar o jogo da arte conceito do Gemini, com lucky blocks de doce, m?quinas de chiclete,
pets 3D fofos, HUD com moedas e gemas no topo e menu lateral, confete e efeitos de moedas.
O pipeline de arte, j? provado com o Urso de Goma (PR `a/arte-urso-goma`), est? em
`art/README.md`: refer?ncia -> Blender via MCP (Codex) -> bake de textura -> Import 3D no Studio ->
`.rbxm` em `assets/` -> `tools/art/prepare_pet.luau`. Objetos opacos simples tamb?m podem usar
`generate_mesh` do MCP do Studio.

### Squad A: Mundo e Experi?ncia

**A11 ? Blocos em 3D** (`rbx-design` + Studio)
- Arquivos prov?veis: `assets/`, `tools/map/`.
- Criar os 4 tipos de bloco no estilo lucky block de doce.
- Pronto quando: os 4 modelos aparecem nos lugares corretos e funcionam ao serem atingidos e quebrados.

**A12 ? Decora??o 3D das 3 ?reas** (`rbx-design` + Studio)
- Arquivos prov?veis: `assets/`, `tools/map/`.
- Criar arco "Candy Plaza", morros de doce, piso com granulado e port?o de biscoito.
- Pronto quando: as 3 ?reas t?m decora??o coerente com a arte conceito e permitem a navega??o.

**A13 ? HUD novo no estilo da arte** (`rbx-design` + `rbx-client`)
- Arquivos prov?veis: `src/client/UI/Hud/`, `src/client/Controllers/HudController.luau`.
- Moedas e gemas no topo com "+", contador de Rebirth, menu lateral Shop/Pets/Invent?rio/Configura??es,
  bot?es Auto-Click e x3 Ovos; usar ?cones do ForgeGUI.
- Pronto quando: o HUD ? leg?vel e seus controles funcionam em celular e PC.

**A14 ? Efeitos** (`rbx-design` + `rbx-client`)
- Arquivos prov?veis: `assets/`, `src/client/Controllers/BlockController.luau`, `src/client/Controllers/PetController.luau`.
- Confete, "+N moedas" voando, brilho ao quebrar e rastro dos pets.
- Pronto quando: os efeitos aparecem nos eventos correspondentes sem atrapalhar a leitura ou o jogo.

**A15 ? ?reas 4 a 6** (`rbx-design` + Studio; depois das tarefas anteriores)
- Arquivos prov?veis: `assets/`, `tools/map/`, `src/shared/Config/`.
- Criar e decorar as ?reas 4 a 6 seguindo a progress?o e o estilo visual do jogo.
- Pronto quando: as 3 ?reas est?o acess?veis na ordem prevista e t?m blocos e decora??o pr?prios.

### Squad B: Pets e Progress?o

**B10 ? Os 5 pets atuais em 3D** (`rbx-design` + Studio)
- Arquivos prov?veis: `art/`, `assets/`, `tools/art/prepare_pet.luau`.
- Usar o pipeline documentado; BearGummy j? est? feito.
- Pronto quando: os 5 pets atuais aparecem em 3D no jogo, com textura e prepara??o conclu?das.

**B11 ? Mais pets e ovos por ?rea** (`rbx-design` + `rbx-logica` + `rbx-server`)
- Arquivos prov?veis: `docs/balanceamento/`, `src/shared/Config/`, `art/`, `assets/`.
- Criar 15 a 20 pets novos em 5 raridades e 1 ovo por ?rea, incluindo Nuvens de Algod?o;
  n?meros do `rbx-design` (Gemini) em `docs/balanceamento/`.
- Pronto quando: pets e ovos est?o dispon?veis nas ?reas correspondentes, com chances e n?meros documentados.

**B12 ? Ovos como m?quinas de chiclete 3D** (`rbx-design` + `rbx-client` + Studio)
- Arquivos prov?veis: `art/`, `assets/`, `src/client/Controllers/EggController.luau`, `src/client/UI/Eggs/`.
- Criar as m?quinas e a anima??o de chocar.
- Pronto quando: cada ovo usa uma m?quina 3D e a anima??o revela o pet comprado.

**B13 ? Pets animados e arco-?ris** (`rbx-design` + `rbx-client` + `rbx-server`)
- Arquivos prov?veis: `src/client/Controllers/PetController.luau`, `src/server/Services/PetService.luau`, `src/shared/Config/`.
- Animar pets flutuando ou pulando e criar pets arco-?ris por fus?o de dourados usando `Variant`.
- Pronto quando: os pets se animam ao seguir jogadores e a fus?o de dourados produz a variante arco-?ris.

### Integra??o

**I5 ? Playtest visual** (as duas squads + testador)
- Arquivos prov?veis: `docs/` (registro do playtest).
- Pronto quando: celular e PC s?o avaliados e os problemas visuais encontrados s?o registrados.

**I6 ? Revis?o de desempenho** (as duas squads + testador)
- Arquivos prov?veis: `docs/` (registro das medi??es), `assets/`.
- Medir FPS e mem?ria em celular fraco e definir limite de tri?ngulos.
- Pronto quando: medi??es e limite est?o documentados e os assets atendem ao limite definido.

---

## Fase 4: ideias

Troca de pets (alto risco de duplicação: só com o jogo publicado e logs de economia),
pets arco-íris, mais áreas, eventos de fim de semana.
