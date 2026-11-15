# Especificação de Mapa: Praça dos Doces (`CandyPlaza`) e Modelos de Bloco

**Dono:** Squad A (`rbx-design`)  
**Caminhos no Roblox Studio:**
- `Workspace.Areas.CandyPlaza`
- `ServerStorage.BlockTemplates`

Este documento especifica a construção geométrica completa da área inicial **CandyPlaza** ("Praça dos Doces") e dos 4 modelos de Lucky Blocks (`GummyBlock`, `LollipopBlock`, `ChocoBlock`, `CloudBlock`) usando **exclusivamente Parts nativas do Roblox** (`Block`, `Ball`, `Cylinder`, `Wedge`), sem malhas (`MeshPart`) nem texturas/imagens externas.

> **Nota sobre Cilindros no Roblox:** Uma `Part` com `Shape = Enum.PartType.Cylinder` tem o eixo de comprimento no **eixo X** local (`Size.X` = altura/comprimento do cilindro; `Size.Y` e `Size.Z` = diâmetro). Para deixá-lo em pé (eixo no Y do mundo), aplica-se rotação `Orientation = (0, 0, 90)`. Para deixá-lo apontando no eixo Z, aplica-se `Orientation = (0, 90, 0)`.

---

## 1. Medidas, Coordenadas e Estrutura de Pastas

- **Limites da área (`CandyPlaza`):** ocupa `X` de `-70` a `70` (140 studs) e `Z` de `-70` a `70` (140 studs).
- **Nível do chão:** superfície pisável da base em `Y = 0` (`BaseFloor` com `Size = (140, 2, 140)` centrado em `Y = -1`, sobrepondo o Baseplate cinza do Studio). Caminhos e praça central têm `0.2` stud de relevo (`Y = 0.1`, topo em `Y = 0.2`).
- **Passagem para `ChocolateFalls` (lado `+X`):**
  - Fica na borda `X = 70`, com **16 studs de largura** no intervalo `Z` de `-8` a `8`.
  - A mureta leste é dividida em duas partes (`WallEastNorth` de `Z = -70` a `-8` e `WallEastSouth` de `Z = 8` a `70`), deixando o vão livre em `X = 70, Z ∈ [-8, 8]` onde a Squad B posicionará `Workspace.Areas.ChocolateFalls.Gate`.
- **Contagem total de Parts no cenário (`CandyPlaza`):** **54 Parts** (bem abaixo do teto de 120 Parts para garantir 60 FPS em celulares de entrada).

### Hierarquia no `Workspace`
```text
Workspace
└── Areas (Folder)
    └── CandyPlaza (Folder)
        ├── SpawnLocation (SpawnLocation)
        ├── BlockSpawns (Folder)        -- 10 Parts invisíveis com atributo BlockType
        ├── Eggs (Folder)               -- A Squad B coloca o Model CandyEgg aqui
        ├── Scenery (Folder)            -- Chão, caminhos, bordas, pedestal do ovo e 8 enfeites
```

---

## 2. Paleta de Cores

Todas as cores foram pensadas para alto contraste, leitura rápida em telas pequenas (mobile) e estética "doce pastel / vibrante":

| Nome na Paleta | RGB `(R, G, B)` | Hex | Uso Principal |
|---|---|---|---|
| **Rosa Algodão** | `255, 182, 213` | `#FFB6D5` | Gramado de doce (piso base da `CandyPlaza`) |
| **Creme Baunilha** | `255, 245, 220` | `#FFF5DC` | Caminhos, praça central, palitos de pirulito e bengalas |
| **Branco Açúcar** | `255, 255, 255` | `#FFFFFF` | Listras de doces, glacê, nuvens, olhos de goma |
| **Rosa Chiclete** | `255, 95, 162` | `#FF5FA2` | Muretas de borda, `GummyBlock`, pirulitos e rosquinha |
| **Magenta Doce** | `230, 50, 135` | `#E63287` | Laço do `GummyBlock` e listras secundárias |
| **Vermelho Morango** | `255, 65, 90` | `#FF415A` | Listras das bengalas, cereja e enfeites |
| **Azul Céu Doce** | `115, 215, 255` | `#73D7FF` | `LollipopBlock`, pirulito gigante azul e anel do pedestal |
| **Amarelo Limão** | `255, 230, 95` | `#FFE65F` | Laços, granulados, miolo de pirulito e gomas |
| **Verde Menta** | `120, 240, 180` | `#78F0B4` | Cantoneiras, pirulito menta, goma verde e granulados |
| **Laranja Tangerina** | `255, 155, 70` | `#FF9B46` | Goma laranja e pirulito cítrico |
| **Roxo Uva** | `185, 130, 255` | `#B982FF` | `CloudBlock`, detalhes mágicos e cristais de açúcar |
| **Marrom Ao Leite** | `120, 72, 42` | `#78482A` | Corpo do `ChocoBlock` |
| **Marrom Cacau** | `75, 40, 22` | `#4B2816` | Cobertura escura do `ChocoBlock` |
| **Caramelo Dourado** | `245, 185, 75` | `#F5B94B` | Laço do `ChocoBlock` e base do pedestal do ovo |
| **Massa de Donut** | `240, 195, 135` | `#F0C387` | Base da rosquinha gigante |

---

## 3. `SpawnLocation` do Jogador

Fica no quadrante oeste da praça central, já virado para o centro da área e para a saída leste (`+X`, rumo a `ChocolateFalls`).

| Nome | Classe | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Orientation `(X, Y, Z)` | Color `(R, G, B)` | Material | Propriedades Extras |
|---|---|---|---|---|---|---|---|---|
| `SpawnLocation` | `SpawnLocation` | `Block` | `8, 1, 8` | `-18, 0.5, 0` | `0, -90, 0` | `255, 230, 95` | `SmoothPlastic` | `Anchored = true`, `CanCollide = true`, `Neutral = true`, `Transparency = 0` |

> **Nota:** Se o decal padrão do `SpawnLocation` for removido, mantenha apenas a Part limpa na cor Amarelo Limão (`255, 230, 95`).

---

## 4. Lugar Reservado para o Ovo `CandyEgg`

O pedestal fica ao norte da praça central, bem visível a partir do `SpawnLocation` e com caminho pavimentado direto (`PathNorth`), sem obstruir os `BlockSpawns`.

- **Posição do centro do pedestal:** `(0, 0, -28)`
- **Ponto de apoio (topo do pedestal) onde a Squad B deve posicionar `Workspace.Areas.CandyPlaza.Eggs.CandyEgg`:**
  - **Posição do Pivot / base do ovo:** `(0, 2.6, -28)` (ou centro do `PrimaryPart` em `(0, 5.0, -28)` para um ovo de ~5 studs de altura).
  - **Raio livre ao redor:** 10 studs sem nenhum obstáculo para o jogador se aproximar e acionar `PurchaseEgg("CandyEgg")`.

As 3 Parts que formam o pedestal já estão incluídas na tabela de cenário da Seção 6 (`EggPedestalBase`, `EggPedestalTop`, `EggPedestalRing`).

---

## 5. `BlockSpawns` (10 Posições)

Pasta `Workspace.Areas.CandyPlaza.BlockSpawns`.  
Todas as 10 Parts têm:
- `ClassName = "Part"`, `Shape = Block`
- `Size = Vector3.new(1, 1, 1)`
- `Position.Y = 3` (como o bloco tem `4x4x4`, seu centro em `Y = 2` ou apoiado a partir do spawn fica alinhado ao chão)
- `Anchored = true`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `Transparency = 1`
- Atributo `BlockType` (`string`) definido na própria Part.

### Tabela de `BlockSpawns`

| Nome da Part | Position `(X, Y, Z)` | Atributo `BlockType` | Dist. ao `SpawnLocation` `(-18, 0.5, 0)` | Dist. mínima a outro `BlockSpawn` | Zona |
|---|---|---|---|---|---|
| `Spawn_Gummy_01` | `-4, 3, -12` | `"GummyBlock"` | `18.6` studs | `14.0` studs (`Gummy_03`) | Anel interno (perto do spawn) |
| `Spawn_Gummy_02` | `-4, 3, 12` | `"GummyBlock"` | `18.6` studs | `14.0` studs (`Gummy_04`) | Anel interno (perto do spawn) |
| `Spawn_Gummy_03` | `10, 3, -12` | `"GummyBlock"` | `30.6` studs | `14.0` studs (`Gummy_01`) | Anel interno (perto do spawn) |
| `Spawn_Gummy_04` | `10, 3, 12` | `"GummyBlock"` | `30.6` studs | `14.0` studs (`Gummy_02`) | Anel interno (perto do spawn) |
| `Spawn_Gummy_05` | `-18, 3, -20` | `"GummyBlock"` | `20.2` studs | `16.1` studs (`Gummy_01`) | Anel interno (noroeste do spawn) |
| `Spawn_Gummy_06` | `-18, 3, 20` | `"GummyBlock"` | `20.2` studs | `16.1` studs (`Gummy_02`) | Anel interno (sudoeste do spawn) |
| `Spawn_Lollipop_01` | `28, 3, -24` | `"LollipopBlock"` | `52.0` studs | `21.6` studs (`Gummy_03`) | Anel externo (nordeste) |
| `Spawn_Lollipop_02` | `28, 3, 24` | `"LollipopBlock"` | `52.0` studs | `21.6` studs (`Gummy_04`) | Anel externo (sudeste) |
| `Spawn_Lollipop_03` | `38, 3, -10` | `"LollipopBlock"` | `56.9` studs | `17.2` studs (`Lollipop_01`) | Anel externo (leste-norte, perto da saída) |
| `Spawn_Lollipop_04` | `38, 3, 10` | `"LollipopBlock"` | `56.9` studs | `17.2` studs (`Lollipop_02`) | Anel externo (leste-sul, perto da saída) |

> **Verificação de espaçamento:** a menor distância entre dois `BlockSpawns` é **14.0 studs** (requisito mínimo: 12 studs) e a menor distância ao `SpawnLocation` é **18.6 studs** (requisito mínimo: 12 studs). Nenhum bloco fica sobre o corredor central (`Z ∈ [-8, 8]`) que leva à passagem de `ChocolateFalls`.

---

## 6. Tabela de Parts do Cenário (`Workspace.Areas.CandyPlaza.Scenery`)

Todas as Parts abaixo possuem **`Anchored = true`**.  
Salvo indicação na coluna de observações, todas possuem `CanCollide = true` e `Transparency = 0`.

### 6.1. Chão, Caminhos, Bordas, Portal de Passagem e Pedestal do Ovo (22 Parts)

| # | Nome | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Orientation `(X, Y, Z)` | Color `(R, G, B)` | Material | Notas |
|---|---|---|---|---|---|---|---|---|
| 1 | `BaseFloor` | `Block` | `140, 2, 140` | `0, -1, 0` | `0, 0, 0` | `255, 182, 213` | `SmoothPlastic` | Topo em `Y = 0` |
| 2 | `PlazaCenterDisc` | `Cylinder` | `0.2, 44, 44` | `0, 0.1, 0` | `0, 0, 90` | `255, 245, 220` | `SmoothPlastic` | Praça redonda central |
| 3 | `PathEastWest` | `Block` | `104, 0.2, 14` | `18, 0.1, 0` | `0, 0, 0` | `255, 245, 220` | `SmoothPlastic` | Vai de `X = -34` até a saída `X = 70` |
| 4 | `PathNorth` | `Block` | `12, 0.2, 24` | `0, 0.1, -18` | `0, 0, 0` | `255, 245, 220` | `SmoothPlastic` | Liga a praça ao pedestal do `CandyEgg` |
| 5 | `PathSouth` | `Block` | `12, 0.2, 24` | `0, 0.1, 18` | `0, 0, 0` | `255, 245, 220` | `SmoothPlastic` | Simetria sul da praça |
| 6 | `WallNorth` | `Block` | `140, 5, 2` | `0, 2.5, -69` | `0, 0, 0` | `255, 95, 162` | `SmoothPlastic` | Mureta norte |
| 7 | `WallSouth` | `Block` | `140, 5, 2` | `0, 2.5, 69` | `0, 0, 0` | `255, 95, 162` | `SmoothPlastic` | Mureta sul |
| 8 | `WallWest` | `Block` | `2, 5, 140` | `-69, 2.5, 0` | `0, 0, 0` | `255, 95, 162` | `SmoothPlastic` | Mureta oeste |
| 9 | `WallEastNorth` | `Block` | `2, 5, 62` | `69, 2.5, -39` | `0, 0, 0` | `255, 95, 162` | `SmoothPlastic` | Vai de `Z = -70` até `Z = -8` |
| 10 | `WallEastSouth` | `Block` | `2, 5, 62` | `69, 2.5, 39` | `0, 0, 0` | `255, 95, 162` | `SmoothPlastic` | Vai de `Z = 8` até `Z = 70` (deixa 16 studs livres) |
| 11 | `CornerPostNW` | `Cylinder` | `8, 5, 5` | `-68, 4, -68` | `0, 0, 90` | `120, 240, 180` | `SmoothPlastic` | Pilar canto NO |
| 12 | `CornerPostSW` | `Cylinder` | `8, 5, 5` | `-68, 4, 68` | `0, 0, 90` | `120, 240, 180` | `SmoothPlastic` | Pilar canto SO |
| 13 | `CornerPostNE` | `Cylinder` | `8, 5, 5` | `68, 4, -68` | `0, 0, 90` | `120, 240, 180` | `SmoothPlastic` | Pilar canto NE |
| 14 | `CornerPostSE` | `Cylinder` | `8, 5, 5` | `68, 4, 68` | `0, 0, 90` | `120, 240, 180` | `SmoothPlastic` | Pilar canto SE |
| 15 | `GatePillarNorth` | `Cylinder` | `12, 3.5, 3.5` | `69, 6, -9.75` | `0, 0, 90` | `255, 245, 220` | `SmoothPlastic` | Moldura norte da passagem (`Z = -8` livre) |
| 16 | `GatePillarSouth` | `Cylinder` | `12, 3.5, 3.5` | `69, 6, 9.75` | `0, 0, 90` | `255, 245, 220` | `SmoothPlastic` | Moldura sul da passagem (`Z = 8` livre) |
| 17 | `GateCapNorth` | `Ball` | `4.5, 4.5, 4.5` | `69, 12.5, -9.75` | `0, 0, 0` | `255, 230, 95` | `Neon` | Topo brilhante do pilar norte |
| 18 | `GateCapSouth` | `Ball` | `4.5, 4.5, 4.5` | `69, 12.5, 9.75` | `0, 0, 0` | `255, 230, 95` | `Neon` | Topo brilhante do pilar sul |
| 19 | `EggPedestalBase` | `Cylinder` | `1.4, 12, 12` | `0, 0.7, -28` | `0, 0, 90` | `245, 185, 75` | `SmoothPlastic` | Base do pedestal do `CandyEgg` |
| 20 | `EggPedestalTop` | `Cylinder` | `1.2, 9, 9` | `0, 2.0, -28` | `0, 0, 90` | `255, 245, 220` | `SmoothPlastic` | Topo em `Y = 2.6` (onde senta o `CandyEgg`) |
| 21 | `EggPedestalRing` | `Cylinder` | `0.4, 10, 10` | `0, 1.5, -28` | `0, 0, 90` | `115, 215, 255` | `Neon` | Anel luminoso de destaque |
| 22 | `SpawnPadRing` | `Cylinder` | `0.3, 11, 11` | `-18, 0.15, 0` | `0, 0, 90` | `255, 95, 162` | `SmoothPlastic` | Moldura circular sob o `SpawnLocation` |

---

### 6.2. Enfeites Gigantes (8 Enfeites = 32 Parts)

Todos os 8 enfeites ficam nas bordas e cantos da área (`|X| ≥ 38` ou `|Z| ≥ 44`), deixando o centro, os `BlockSpawns`, o `CandyEgg` e a passagem em `X = 70` totalmente desimpedidos.

| # | Enfeite | Nome da Part | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Orientation `(X, Y, Z)` | Color `(R, G, B)` | Material |
|---|---|---|---|---|---|---|---|---|
| 23 | **1. Pirulito Gigante Rosa (NO)** | `LollipopNW_Stick` | `Cylinder` | `14, 1.2, 1.2` | `-48, 7, -48` | `0, 0, 90` | `255, 245, 220` | `SmoothPlastic` |
| 24 | | `LollipopNW_Candy` | `Cylinder` | `2.2, 10, 10` | `-48, 15, -48` | `0, 45, 0` | `255, 95, 162` | `SmoothPlastic` |
| 25 | | `LollipopNW_Swirl` | `Cylinder` | `2.4, 6, 6` | `-48, 15, -48` | `0, 45, 0` | `255, 255, 255` | `SmoothPlastic` |
| 26 | | `LollipopNW_Core` | `Cylinder` | `2.6, 2.5, 2.5` | `-48, 15, -48` | `0, 45, 0` | `255, 230, 95` | `Neon` |
| 27 | **2. Pirulito Gigante Azul (SO)** | `LollipopSW_Stick` | `Cylinder` | `14, 1.2, 1.2` | `-48, 7, 48` | `0, 0, 90` | `255, 245, 220` | `SmoothPlastic` |
| 28 | | `LollipopSW_Candy` | `Cylinder` | `2.2, 10, 10` | `-48, 15, 48` | `0, -45, 0` | `115, 215, 255` | `SmoothPlastic` |
| 29 | | `LollipopSW_Swirl` | `Cylinder` | `2.4, 6, 6` | `-48, 15, 48` | `0, -45, 0` | `255, 255, 255` | `SmoothPlastic` |
| 30 | | `LollipopSW_Core` | `Cylinder` | `2.6, 2.5, 2.5` | `-48, 15, 48` | `0, -45, 0` | `255, 95, 162` | `Neon` |
| 31 | **3. Pirulito Gigante Menta (NE)** | `LollipopNE_Stick` | `Cylinder` | `16, 1.4, 1.4` | `48, 8, -50` | `0, 0, 90` | `255, 245, 220` | `SmoothPlastic` |
| 32 | | `LollipopNE_Candy` | `Cylinder` | `2.4, 11, 11` | `48, 17, -50` | `0, 30, 0` | `120, 240, 180` | `SmoothPlastic` |
| 33 | | `LollipopNE_Swirl` | `Cylinder` | `2.6, 6.5, 6.5` | `48, 17, -50` | `0, 30, 0` | `255, 255, 255` | `SmoothPlastic` |
| 34 | **4. Pirulito Gigante Laranja (SE)** | `LollipopSE_Stick` | `Cylinder` | `16, 1.4, 1.4` | `48, 8, 50` | `0, 0, 90` | `255, 245, 220` | `SmoothPlastic` |
| 35 | | `LollipopSE_Candy` | `Cylinder` | `2.4, 11, 11` | `48, 17, 50` | `0, -30, 0` | `255, 155, 70` | `SmoothPlastic` |
| 36 | | `LollipopSE_Swirl` | `Cylinder` | `2.6, 6.5, 6.5` | `48, 17, 50` | `0, -30, 0` | `255, 230, 95` | `SmoothPlastic` |
| 37 | **5. Bengala de Doce Norte** | `CaneN_Stem1` | `Cylinder` | `4, 2.2, 2.2` | `-24, 2, -46` | `0, 0, 90` | `255, 255, 255` | `SmoothPlastic` |
| 38 | | `CaneN_Stem2` | `Cylinder` | `4, 2.3, 2.3` | `-24, 6, -46` | `0, 0, 90` | `255, 65, 90` | `SmoothPlastic` |
| 39 | | `CaneN_Stem3` | `Cylinder` | `4, 2.2, 2.2` | `-24, 10, -46` | `0, 0, 90` | `255, 255, 255` | `SmoothPlastic` |
| 40 | | `CaneN_TopBar` | `Cylinder` | `5, 2.3, 2.3` | `-22, 12.5, -46` | `0, 0, 0` | `255, 65, 90` | `SmoothPlastic` |
| 41 | | `CaneN_HookTip` | `Cylinder` | `3, 2.2, 2.2` | `-20, 10.5, -46` | `0, 0, 90` | `255, 255, 255` | `SmoothPlastic` |
| 42 | **6. Bengala de Doce Sul** | `CaneS_Stem1` | `Cylinder` | `4, 2.2, 2.2` | `-24, 2, 46` | `0, 0, 90` | `255, 255, 255` | `SmoothPlastic` |
| 43 | | `CaneS_Stem2` | `Cylinder` | `4, 2.3, 2.3` | `-24, 6, 46` | `0, 0, 90` | `255, 65, 90` | `SmoothPlastic` |
| 44 | | `CaneS_Stem3` | `Cylinder` | `4, 2.2, 2.2` | `-24, 10, 46` | `0, 0, 90` | `255, 255, 255` | `SmoothPlastic` |
| 45 | | `CaneS_TopBar` | `Cylinder` | `5, 2.3, 2.3` | `-22, 12.5, 46` | `0, 0, 0` | `255, 65, 90` | `SmoothPlastic` |
| 46 | | `CaneS_HookTip` | `Cylinder` | `3, 2.2, 2.2` | `-20, 10.5, 46` | `0, 0, 90` | `255, 255, 255` | `SmoothPlastic` |
| 47 | **7. Rosquinha Gigante (Oeste)** | `DonutW_Dough` | `Cylinder` | `3.5, 14, 14` | `-50, 7, 0` | `0, 90, 0` | `240, 195, 135` | `SmoothPlastic` |
| 48 | | `DonutW_Icing` | `Cylinder` | `3.8, 12.5, 12.5` | `-49.6, 7.3, 0` | `0, 90, 0` | `255, 95, 162` | `SmoothPlastic` |
| 49 | | `DonutW_Sprinkle1` | `Block` | `0.6, 2.2, 0.8` | `-47.6, 10.5, -2.5` | `25, 0, 0` | `255, 230, 95` | `SmoothPlastic` |
| 50 | | `DonutW_Sprinkle2` | `Block` | `0.6, 2.2, 0.8` | `-47.6, 10.5, 2.5` | `-25, 0, 0` | `120, 240, 180` | `SmoothPlastic` |
| 51 | | `DonutW_Sprinkle3` | `Block` | `0.6, 2.2, 0.8` | `-47.6, 4.5, 0` | `70, 0, 0` | `115, 215, 255` | `SmoothPlastic` |
| 52 | **8. Trio de Gomas (Sul)** | `Gumdrop_Pink` | `Ball` | `7, 7, 7` | `0, 3, 50` | `0, 0, 0` | `255, 95, 162` | `Glass` |
| 53 | | `Gumdrop_Mint` | `Ball` | `5.5, 5.5, 5.5` | `-7, 2.2, 53` | `0, 0, 0` | `120, 240, 180` | `Glass` |
| 54 | | `Gumdrop_Yellow` | `Ball` | `5.5, 5.5, 5.5` | `7, 2.2, 53` | `0, 0, 0` | `255, 230, 95` | `Glass` |

---

## 7. Modelos de Bloco (`ServerStorage.BlockTemplates.<BlockType>`)

Cada tipo de bloco é um `Model` salvo em `ServerStorage.BlockTemplates.<BlockType>`.

### Regras Gerais para Todos os 4 Modelos
1. **`Model.PrimaryPart`** aponta obrigatoriamente para a Part chamada **`Core`**.
2. **`Core`:** `Shape = Block`, `Size = Vector3.new(4, 4, 4)`, `Anchored = true`, **`CanCollide = true`**.
3. **Parts de detalhe:** todas têm `Anchored = true`, **`CanCollide = false`**, `CanQuery = false`, `CanTouch = false`.
4. **Coordenadas relativas:** na tabela de cada bloco, a coluna `Offset Relativo ao Core (dX, dY, dZ)` indica a posição da Part quando `Core.Position = (0, 0, 0)` (ou seja, `Part.Position = Core.Position + Vector3.new(dX, dY, dZ)`).

---

### 7.1. `GummyBlock` ("Bloco de Goma") — `Core` + 5 Parts de Detalhe

Cubo de goma rosa translúcida com fita cruzada magenta e dois olhinhos doces na face frontal (`-Z`).

| Nome da Part | Shape | Size `(X, Y, Z)` | Offset Relativo ao `Core` `(dX, dY, dZ)` | Orientation `(X, Y, Z)` | Color `(R, G, B)` | Material | `CanCollide` |
|---|---|---|---|---|---|---|---|
| `Core` | `Block` | `4, 4, 4` | `0, 0, 0` | `0, 0, 0` | `255, 95, 162` | `Glass` | **`true`** |
| `RibbonX` | `Block` | `4.2, 4.2, 0.8` | `0, 0, 0` | `0, 0, 0` | `230, 50, 135` | `SmoothPlastic` | `false` |
| `RibbonZ` | `Block` | `0.8, 4.2, 4.2` | `0, 0, 0` | `0, 0, 0` | `230, 50, 135` | `SmoothPlastic` | `false` |
| `TopBow` | `Ball` | `1.4, 0.9, 1.4` | `0, 2.2, 0` | `0, 0, 0` | `255, 230, 95` | `SmoothPlastic` | `false` |
| `EyeLeft` | `Cylinder` | `0.2, 0.7, 0.7` | `-0.8, 0.4, -2.05` | `0, 90, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `EyeRight` | `Cylinder` | `0.2, 0.7, 0.7` | `0.8, 0.4, -2.05` | `0, 90, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |

---

### 7.2. `LollipopBlock` ("Bloco Pirulito") — `Core` + 5 Parts de Detalhe

Bloco azul-céu com faixas brancas de embrulho, medallhão de pirulito nas faces e laço duplo em `Wedge` no topo.

| Nome da Part | Shape | Size `(X, Y, Z)` | Offset Relativo ao `Core` `(dX, dY, dZ)` | Orientation `(X, Y, Z)` | Color `(R, G, B)` | Material | `CanCollide` |
|---|---|---|---|---|---|---|---|
| `Core` | `Block` | `4, 4, 4` | `0, 0, 0` | `0, 0, 0` | `115, 215, 255` | `SmoothPlastic` | **`true`** |
| `StripeHorizontal` | `Block` | `4.2, 0.9, 4.2` | `0, 0, 0` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `StripeVertical` | `Block` | `0.9, 4.2, 4.2` | `0, 0, 0` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `SwirlDiskZ` | `Cylinder` | `4.3, 2.4, 2.4` | `0, 0, 0` | `0, 90, 0` | `255, 95, 162` | `SmoothPlastic` | `false` |
| `BowWingLeft` | `Wedge` | `0.9, 0.8, 1.3` | `-0.65, 2.3, 0` | `0, 90, 0` | `255, 230, 95` | `SmoothPlastic` | `false` |
| `BowWingRight` | `Wedge` | `0.9, 0.8, 1.3` | `0.65, 2.3, 0` | `0, -90, 0` | `255, 230, 95` | `SmoothPlastic` | `false` |

---

### 7.3. `ChocoBlock` ("Bloco de Chocolate") — `Core` + 6 Parts de Detalhe

Bloco de chocolate ao leite com cobertura de calda de cacau escuro no topo, fita dourada, granulado colorido e cereja brilhante no topo.

| Nome da Part | Shape | Size `(X, Y, Z)` | Offset Relativo ao `Core` `(dX, dY, dZ)` | Orientation `(X, Y, Z)` | Color `(R, G, B)` | Material | `CanCollide` |
|---|---|---|---|---|---|---|---|
| `Core` | `Block` | `4, 4, 4` | `0, 0, 0` | `0, 0, 0` | `120, 72, 42` | `SmoothPlastic` | **`true`** |
| `FudgeTop` | `Block` | `4.2, 1.0, 4.2` | `0, 1.6, 0` | `0, 0, 0` | `75, 40, 22` | `SmoothPlastic` | `false` |
| `CaramelBand` | `Block` | `4.15, 0.6, 4.15` | `0, -0.5, 0` | `0, 0, 0` | `245, 185, 75` | `SmoothPlastic` | `false` |
| `WhippedCream` | `Cylinder` | `0.5, 1.8, 1.8` | `0, 2.25, 0` | `0, 0, 90` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `CherryTop` | `Ball` | `1.0, 1.0, 1.0` | `0, 2.8, 0` | `0, 0, 0` | `255, 65, 90` | `Neon` | `false` |
| `SprinklePink` | `Block` | `0.3, 0.2, 0.9` | `-1.1, 2.15, -0.9` | `0, 35, 0` | `255, 95, 162` | `SmoothPlastic` | `false` |
| `SprinkleMint` | `Block` | `0.3, 0.2, 0.9` | `1.1, 2.15, 0.9` | `0, -40, 0` | `120, 240, 180` | `SmoothPlastic` | `false` |

---

### 7.4. `CloudBlock` ("Bloco de Nuvem") — `Core` + 5 Parts de Detalhe

Bloco de algodão-doce lilás cercado de esferas de nuvem brancas fofinhas, cinta mágica neon e estrela de açúcar dourada no topo.

| Nome da Part | Shape | Size `(X, Y, Z)` | Offset Relativo ao `Core` `(dX, dY, dZ)` | Orientation `(X, Y, Z)` | Color `(R, G, B)` | Material | `CanCollide` |
|---|---|---|---|---|---|---|---|
| `Core` | `Block` | `4, 4, 4` | `0, 0, 0` | `0, 0, 0` | `185, 130, 255` | `SmoothPlastic` | **`true`** |
| `CloudPuffNW` | `Ball` | `2.2, 1.6, 2.2` | `-1.2, -1.2, -1.2` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `CloudPuffNE` | `Ball` | `2.2, 1.6, 2.2` | `1.2, -1.2, 1.2` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `CloudPuffTop` | `Ball` | `3.2, 1.4, 3.2` | `0, 1.7, 0` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `NeonHalo` | `Block` | `4.25, 0.5, 4.25` | `0, 0.2, 0` | `0, 0, 0` | `115, 215, 255` | `Neon` | `false` |
| `StarGemTop` | `Block` | `1.1, 1.1, 1.1` | `0, 2.5, 0` | `45, 45, 0` | `255, 230, 95` | `Neon` | `false` |
