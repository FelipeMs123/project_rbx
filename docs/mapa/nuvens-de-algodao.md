# Especificação de Mapa: Nuvens de Algodão (`CottonClouds`)

**Dono:** Squad A (`rbx-design`)  
**Caminho no Roblox Studio:**
- `Workspace.Areas.CottonClouds`

Este documento especifica a construção geométrica completa da Área 3 **CottonClouds** ("Nuvens de Algodão", tarefa **A7** do `docs/ROADMAP.md`) usando **exclusivamente Parts nativas do Roblox** (`Block`, `Ball`, `Cylinder`), sem malhas (`MeshPart`) nem texturas externas, mantendo o mesmo padrão de `docs/mapa/praca-dos-doces.md` e total coerência geométrica com `tools/map/ChocolateFalls.luau`.

> **Nota sobre Cilindros no Roblox:** Uma `Part` com `Shape = Enum.PartType.Cylinder` tem o eixo de comprimento no **eixo X** local (`Size.X` = altura/comprimento do cilindro; `Size.Y` e `Size.Z` = diâmetro). Para deixá-lo em pé (eixo no Y do mundo), aplica-se rotação `Rotation = (0, 0, 90)`.

---

## 1. Medidas, Coordenadas, Transição com `ChocolateFalls` e Estrutura de Pastas

- **Limites da área (`CottonClouds`):** ocupa `X` de `212` a `352` (`140` studs, centro em `X = 282`) e `Z` de `-70` a `70` (`140` studs, centro em `Z = 0`).
- **Nível do chão e continuidade com a Cascata (`ChocolateFalls`):**
  - Na `ChocolateFalls`, o `BaseFloor` ocupa `X` de `70` a `210` (`Position = (140, -0.9, 0)`, `Size = (140, 2, 140)`, topo pisável em `Y = 0.1`), as paredes leste (`WallEastNorth` e `WallEastSouth`) ficam em `X = 209` com vão livre em `Z ∈ [-8, 8]`, os pilares `EastGatePillarNorth` e `EastGatePillarSouth` ficam em `X = 209, Z = ±9.75` (`Size = (12, 3.5, 3.5)`, cuja caixa sem rotação cobriria `X ∈ [203, 215]`) e o `Bounds` da cascata cobre `X ∈ [71.5, 210.5]`.
  - Na `CottonClouds`, o `BaseFloor` tem `Size = (140, 2, 140)` centrado em `(282, -0.9, 0)` (cobrindo `X ∈ [212, 352]`, topo em `Y = 0.1`). A peça `EntranceBridge` (`Size = (16, 0.2, 14)` em `(218, 0.1, 0)`, cobrindo `X ∈ [210, 226]`) une o piso da cascata (`X = 210`) ao piso das nuvens (`X = 212`) sem degrau nem fresta, permitindo caminhar direto de uma área para a outra.
  - O vidro `EastGateBarrier` da `ChocolateFalls` (`X = 209`) será removido pelo líder; os pilares `EastGatePillarNorth/South` e topos `EastGateCapNorth/South` da cascata permanecem como moldura da passagem.
- **Passagem de entrada e `Gate` (`X = 212`):**
  - Fica na borda oeste `X = 212`, com **16 studs de largura** no intervalo `Z` de `-8` a `8`.
  - A mureta baixa oeste é dividida em duas partes (`WallWestNorth` de `Z = -70` a `-8` e `WallWestSouth` de `Z = 8` a `70`), deixando o vão `Z ∈ [-8, 8]` livre onde fica `Workspace.Areas.CottonClouds.Gate`.
  - Demais bordas (norte, sul e leste) são fechadas com mureta baixa de `2` studs de altura (`Size.Y = 2`).
- **Contagem total de Parts em `Workspace.Areas.CottonClouds`:** **67 Parts** no total (**50 Parts** no cenário `Scenery`, bem abaixo do teto de ~60 Parts para garantir 60 FPS no celular, + **5 Parts** no `Gate` + **10 Parts** em `BlockSpawns` + **1** `SpawnLocation` + **1** `Bounds`).

### Hierarquia no `Workspace`
```text
Workspace
└── Areas (Folder)
    └── CottonClouds (Folder)
        ├── Bounds (Part)               -- Caixa invisível da área (X 213..352, Y -80..400, Z -70..70)
        ├── SpawnLocation (SpawnLocation) -- Filho direto em (230, 0.5, 0), Enabled = false
        ├── BlockSpawns (Folder)        -- 10 Parts invisíveis (6 CloudBlock + 4 ChocoBlock)
        ├── Gate (Model)                -- Portão em X = 212, Z -8..8 (Core + 4 peças decorativas)
        ├── Eggs (Folder)               -- Pasta vazia (ovo da área 3 fica para depois)
        └── Scenery (Folder)            -- 50 Parts: chão, muretas 2 studs, nuvens, arco-íris e estrelas
```

---

## 2. Paleta de Cores ("Céu de Algodão-Doce")

Estética sonhadora em tons pastel de branco, lilás, rosa e azul-bebê, com pontos de luz em amarelo estrela:

| Nome na Paleta | RGB `(R, G, B)` | Hex | Uso Principal |
|---|---|---|---|
| **Lilás Nuvem Suave** | `230, 210, 255` | `#E6D2FF` | Piso base (`BaseFloor`) e nuvens secundárias |
| **Branco Nuvem** | `255, 255, 255` | `#FFFFFF` | Caminhos, topo de nuvens, bases do arco-íris e viga do `Gate` |
| **Rosa Algodão-Doce** | `255, 182, 213` | `#FFB6D5` | Praça central (`CenterCloudDisc`), nuvens, colunas do `Gate` e algodão-doce |
| **Lilás Algodão** | `185, 130, 255` | `#B982FF` | Muretas baixas (`2` studs), vidro `Core` do `Gate`, arco-íris e nuvens |
| **Azul-Bebê Céu** | `145, 220, 255` | `#91DCFF` | Cantoneiras, faixa neon do `Gate`, anéis, nuvens e arco-íris |
| **Rosa Chiclete** | `255, 95, 162` | `#FF5FA2` | Faixa externa do arco-íris |
| **Amarelo Estrela** | `255, 230, 95` | `#FFE65F` | `SpawnLocation`, topo do arco-íris e estrelas `Neon` pequenas |
| **Creme Baunilha** | `255, 245, 220` | `#FFF5DC` | Palito do cone de algodão-doce gigante |

---

## 3. `Bounds` e `SpawnLocation`

Filhos diretos de `Workspace.Areas.CottonClouds`.

- **`Bounds`:** começa em `X = 213` (depois dos pilares `EastGatePillarNorth/South` da cascata e do próprio `Gate` em `X = 212`) e vai até `X = 352` (`Size.X = 136`, centro `Position.X = 284`), cobrindo `Y` de `-80` a `400` (`Size.Y = 480`, centro `Position.Y = 160`) e `Z` de `-70` a `70` (`Size.Z = 140`, centro `Position.Z = 0`). Possui `CanCollide = false`, `CanQuery = false`, `CanTouch = false` e `Transparency = 1`.
- **`SpawnLocation`:** posicionado logo após a entrada oeste em `(230, 0.5, 0)`, com `Enabled = false` (para o jogador nascer na `CandyPlaza` ao entrar no servidor, mas ser devolvido para cá pelo `AreaService` caso já tenha `CottonClouds` liberada) e `Neutral = true`.

| Nome | Classe | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Rotation `(X, Y, Z)` | Color `(R, G, B)` | Material | `CanCollide` | `Transparency` | Propriedades Extras |
|---|---|---|---|---|---|---|---|---|---|---|
| `Bounds` | `Part` | `Block` | `139, 480, 140` | `282.5, 160, 0` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` | `1` | `Anchored = true`, `CanQuery = false`, `CanTouch = false` |
| `SpawnLocation` | `SpawnLocation` | `Block` | `8, 1, 8` | `230, 0.5, 0` | `0, -90, 0` | `255, 230, 95` | `SmoothPlastic` | `true` | `0` | `Anchored = true`, `Enabled = false`, `Neutral = true` |

---

## 4. Portão de Entrada (`Workspace.Areas.CottonClouds.Gate`) — 5 Parts

`Model` filho de `Workspace.Areas.CottonClouds` posicionado na passagem `X = 212, Z ∈ [-8, 8]`, com `PrimaryPart` apontando para **`Core`**.
- **Regra do fallback ao vivo (`rojo serve`):** o `AreaController` escolhe a Part de menor `Position.Y` quando `PrimaryPart` não vem preenchida no sync ao vivo. Por isso, **`Core` tem `Position.Y = 4.5`** (base em `Y = 0`) e todas as outras 4 peças decorativas têm `Position.Y ≥ 4.6`.
- Todas as 5 Parts têm `Anchored = true` e `CanCollide = true`.

| # | Nome | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Rotation `(X, Y, Z)` | Color `(R, G, B)` | Material | `CanCollide` | `Transparency` | Notas |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `Core` | `Block` | `1.2, 9, 16` | `212, 4.5, 0` | `0, 0, 0` | `185, 130, 255` | `Glass` | `true` | `0.25` | `PrimaryPart`; menor `Position.Y` (`4.5`, base `Y = 0`) |
| 2 | `CloudTopBeam` | `Block` | `1.6, 1.4, 16.4` | `212, 9.5, 0` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `true` | `0` | Viga superior branca de nuvem |
| 3 | `NeonStripeCenter` | `Block` | `1.4, 1.0, 16.2` | `212, 5.0, 0` | `0, 0, 0` | `145, 220, 255` | `Neon` | `true` | `0` | Faixa luminosa azul-bebê central |
| 4 | `PuffColumnNorth` | `Cylinder` | `9, 0.9, 0.9` | `212, 4.6, -4` | `0, 0, 90` | `255, 182, 213` | `SmoothPlastic` | `true` | `0` | Coluna interna norte rosa-algodão (`Y = 4.6 > 4.5`) |
| 5 | `PuffColumnSouth` | `Cylinder` | `9, 0.9, 0.9` | `212, 4.6, 4` | `0, 0, 90` | `255, 182, 213` | `SmoothPlastic` | `true` | `0` | Coluna interna sul rosa-algodão (`Y = 4.6 > 4.5`) |

---

## 5. Pasta `Eggs` Vazia e Pedestal Reservado

- A pasta `Workspace.Areas.CottonClouds.Eggs` deve ser criada **vazia** (`0` Models), pois o ovo da Área 3 fica para uma etapa futura.
- Para manter a identidade visual das áreas anteriores, o pedestal circular já fica pronto no cenário (`EggPedestalBase`, `EggPedestalTop`, `EggPedestalRing`) ao norte da praça central, centrado em `(282, 0, -28)` com topo de apoio em `Y = 2.6`.

---

## 6. `BlockSpawns` (10 Posições: 6 `CloudBlock` e 4 `ChocoBlock`)

Pasta `Workspace.Areas.CottonClouds.BlockSpawns`.  
Seguindo o padrão exato de `CandyPlaza` e `ChocolateFalls`, todas as 10 Parts têm:
- `ClassName = "Part"`, `Shape = "Block"`, `Size = (1, 1, 1)` (marcador invisível onde nasce o modelo `4x4x4` do bloco)
- `Position.Y = 3`, `Rotation = (0, 0, 0)`, `Color = (255, 255, 255)`, `Material = "SmoothPlastic"`
- `Anchored = true`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `Transparency = 1`
- Atributo `BlockType` (`string`): **4 com `"ChocoBlock"`** (quadrante oeste) e **6 com `"CloudBlock"`** (centro e quadrante leste).

### Tabela de `BlockSpawns`

| # | Name | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Rotation `(X, Y, Z)` | Color `(R, G, B)` | Material | `CanCollide` | `Transparency` | Atributo `BlockType` | Dist. mín. a outro Spawn | Dist. mín. à borda |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `Spawn_Choco_01` | `Block` | `1, 1, 1` | `250, 3, -20` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` | `1` | `"ChocoBlock"` | `17.9` studs (`Choco_03`) | `38` studs (oeste) |
| 2 | `Spawn_Choco_02` | `Block` | `1, 1, 1` | `250, 3, 20` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` | `1` | `"ChocoBlock"` | `17.9` studs (`Choco_04`) | `38` studs (oeste) |
| 3 | `Spawn_Choco_03` | `Block` | `1, 1, 1` | `266, 3, -12` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` | `1` | `"ChocoBlock"` | `17.9` studs (`Choco_01`) | `54` studs (oeste) |
| 4 | `Spawn_Choco_04` | `Block` | `1, 1, 1` | `266, 3, 12` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` | `1` | `"ChocoBlock"` | `17.9` studs (`Choco_02`) | `54` studs (oeste) |
| 5 | `Spawn_Cloud_01` | `Block` | `1, 1, 1` | `298, 3, -12` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` | `1` | `"CloudBlock"` | `20.0` studs (`Cloud_03`) | `54` studs (leste) |
| 6 | `Spawn_Cloud_02` | `Block` | `1, 1, 1` | `298, 3, 12` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` | `1` | `"CloudBlock"` | `20.0` studs (`Cloud_04`) | `54` studs (leste) |
| 7 | `Spawn_Cloud_03` | `Block` | `1, 1, 1` | `314, 3, -24` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` | `1` | `"CloudBlock"` | `20.0` studs (`Cloud_01`) | `38` studs (leste) |
| 8 | `Spawn_Cloud_04` | `Block` | `1, 1, 1` | `314, 3, 24` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` | `1` | `"CloudBlock"` | `20.0` studs (`Cloud_02`) | `38` studs (leste) |
| 9 | `Spawn_Cloud_05` | `Block` | `1, 1, 1` | `330, 3, -12` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` | `1` | `"CloudBlock"` | `20.0` studs (`Cloud_03`) | `22` studs (leste) |
| 10 | `Spawn_Cloud_06` | `Block` | `1, 1, 1` | `330, 3, 12` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` | `1` | `"CloudBlock"` | `20.0` studs (`Cloud_04`) | `22` studs (leste) |

> **Verificação de espaçamento:**
> - **Entre `BlockSpawns`:** menor distância é **17.9 studs** (requisito: `≥ 12` studs).
> - **Até as bordas (`X = 212..352`, `Z = -70..70`):** menor distância é **22 studs** até a borda leste e **38 studs** até a borda oeste (requisito: `≥ 10` studs).
> - **Até o `SpawnLocation` `(230, 0.5, 0)`:** menor distância é **28.4 studs**.
> - **Caminhos livres:** nenhum spawn fica sobre o corredor horizontal `PathWestEast` (`Z ∈ [-7, 7]`) nem sobre os caminhos verticais `PathNorth` e `PathSouth` (`X ∈ [276, 288]`).

---

## 7. Tabela de Parts do Cenário (`Workspace.Areas.CottonClouds.Scenery` — 50 Parts)

Todas as 50 Parts abaixo possuem **`Anchored = true`**.

### 7.1. Chão, Ponte, Caminhos, Muretas Baixas (2 studs), Cantoneiras e Pedestal (19 Parts)

| # | Name | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Rotation `(X, Y, Z)` | Color `(R, G, B)` | Material | `CanCollide` | `Transparency` | Notas |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `BaseFloor` | `Block` | `140, 2, 140` | `282, -0.9, 0` | `0, 0, 0` | `230, 210, 255` | `SmoothPlastic` | `true` | `0` | `X ∈ [212, 352]`, topo em `Y = 0.1` |
| 2 | `EntranceBridge` | `Block` | `16, 0.2, 14` | `218, 0.1, 0` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `true` | `0` | Liga `X = 210` (cascata) a `X = 226` sem vão |
| 3 | `CenterCloudDisc` | `Cylinder` | `0.2, 44, 44` | `282, 0.12, 0` | `0, 0, 90` | `255, 182, 213` | `SmoothPlastic` | `true` | `0` | Praça circular central rosa-algodão |
| 4 | `PathWestEast` | `Block` | `124, 0.2, 14` | `288, 0.1, 0` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `true` | `0` | Caminho principal de `X = 226` a `X = 350` |
| 5 | `PathNorth` | `Block` | `12, 0.2, 24` | `282, 0.1, -18` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `true` | `0` | Liga a praça ao pedestal norte |
| 6 | `PathSouth` | `Block` | `12, 0.2, 24` | `282, 0.1, 18` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `true` | `0` | Simetria sul da praça |
| 7 | `WallNorth` | `Block` | `140, 2, 2` | `282, 1, -69` | `0, 0, 0` | `185, 130, 255` | `SmoothPlastic` | `true` | `0` | Mureta baixa norte (`2` studs) |
| 8 | `WallSouth` | `Block` | `140, 2, 2` | `282, 1, 69` | `0, 0, 0` | `185, 130, 255` | `SmoothPlastic` | `true` | `0` | Mureta baixa sul (`2` studs) |
| 9 | `WallEast` | `Block` | `2, 2, 140` | `351, 1, 0` | `0, 0, 0` | `185, 130, 255` | `SmoothPlastic` | `true` | `0` | Mureta baixa leste fechada (`2` studs) |
| 10 | `WallWestNorth` | `Block` | `2, 2, 62` | `213, 1, -39` | `0, 0, 0` | `185, 130, 255` | `SmoothPlastic` | `true` | `0` | Mureta oeste-norte (`Z = -70` a `-8`) |
| 11 | `WallWestSouth` | `Block` | `2, 2, 62` | `213, 1, 39` | `0, 0, 0` | `185, 130, 255` | `SmoothPlastic` | `true` | `0` | Mureta oeste-sul (`Z = 8` a `70`; vão `Z ∈ [-8, 8]`) |
| 12 | `CornerPostNW` | `Cylinder` | `6, 5, 5` | `216, 3, -68` | `0, 0, 90` | `145, 220, 255` | `SmoothPlastic` | `true` | `0` | Pilar canto NO |
| 13 | `CornerPostSW` | `Cylinder` | `6, 5, 5` | `216, 3, 68` | `0, 0, 90` | `145, 220, 255` | `SmoothPlastic` | `true` | `0` | Pilar canto SO |
| 14 | `CornerPostNE` | `Cylinder` | `6, 5, 5` | `350, 3, -68` | `0, 0, 90` | `145, 220, 255` | `SmoothPlastic` | `true` | `0` | Pilar canto NE |
| 15 | `CornerPostSE` | `Cylinder` | `6, 5, 5` | `350, 3, 68` | `0, 0, 90` | `145, 220, 255` | `SmoothPlastic` | `true` | `0` | Pilar canto SE |
| 16 | `EggPedestalBase` | `Cylinder` | `1.4, 12, 12` | `282, 0.7, -28` | `0, 0, 90` | `185, 130, 255` | `SmoothPlastic` | `true` | `0` | Base do pedestal reservado |
| 17 | `EggPedestalTop` | `Cylinder` | `1.2, 9, 9` | `282, 2.0, -28` | `0, 0, 90` | `255, 255, 255` | `SmoothPlastic` | `true` | `0` | Topo em `Y = 2.6` |
| 18 | `EggPedestalRing` | `Cylinder` | `0.4, 10, 10` | `282, 1.5, -28` | `0, 0, 90` | `145, 220, 255` | `Neon` | `true` | `0` | Anel luminoso azul-bebê |
| 19 | `SpawnPadRing` | `Cylinder` | `0.3, 11, 11` | `230, 0.15, 0` | `0, 0, 90` | `145, 220, 255` | `SmoothPlastic` | `true` | `0` | Moldura circular sob o `SpawnLocation` |

---

### 7.2. Enfeites "Céu de Algodão-Doce": Nuvens de `Ball`, Arco-Íris de `Parts`, Algodão-Doce e Estrelas `Neon` (31 Parts)

Todos os enfeites ficam nas bordas (`|Z| ≥ 46` ou `X ≥ 338`), deixando o centro, os `BlockSpawns` e o portão oeste completamente livres.

| # | Enfeite | Name | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Rotation `(X, Y, Z)` | Color `(R, G, B)` | Material | `CanCollide` | `Transparency` |
|---|---|---|---|---|---|---|---|---|---|---|
| 20 | **1. Nuvem Agrupada NO (4 Balls)** | `CloudNW_Center` | `Ball` | `12, 8, 10` | `236, 4.0, -52` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `true` | `0` |
| 21 | | `CloudNW_Left` | `Ball` | `8, 6, 8` | `230, 3.0, -50` | `0, 0, 0` | `255, 182, 213` | `SmoothPlastic` | `true` | `0` |
| 22 | | `CloudNW_Right` | `Ball` | `9, 6.5, 8` | `242, 3.2, -51` | `0, 0, 0` | `145, 220, 255` | `SmoothPlastic` | `true` | `0` |
| 23 | | `CloudNW_Top` | `Ball` | `7, 6, 7` | `236, 7.2, -52` | `0, 0, 0` | `230, 210, 255` | `SmoothPlastic` | `true` | `0` |
| 24 | **2. Nuvem Agrupada SO (4 Balls)** | `CloudSW_Center` | `Ball` | `12, 8, 10` | `236, 4.0, 52` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `true` | `0` |
| 25 | | `CloudSW_Left` | `Ball` | `8, 6, 8` | `230, 3.0, 50` | `0, 0, 0` | `145, 220, 255` | `SmoothPlastic` | `true` | `0` |
| 26 | | `CloudSW_Right` | `Ball` | `9, 6.5, 8` | `242, 3.2, 51` | `0, 0, 0` | `255, 182, 213` | `SmoothPlastic` | `true` | `0` |
| 27 | | `CloudSW_Top` | `Ball` | `7, 6, 7` | `236, 7.2, 52` | `0, 0, 0` | `185, 130, 255` | `SmoothPlastic` | `true` | `0` |
| 28 | **3. Nuvem Agrupada NE (4 Balls)** | `CloudNE_Center` | `Ball` | `13, 8.5, 10` | `328, 4.2, -52` | `0, 0, 0` | `255, 182, 213` | `SmoothPlastic` | `true` | `0` |
| 29 | | `CloudNE_Left` | `Ball` | `8.5, 6, 8` | `321, 3.0, -50` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `true` | `0` |
| 30 | | `CloudNE_Right` | `Ball` | `9, 6.5, 8.5` | `335, 3.2, -51` | `0, 0, 0` | `230, 210, 255` | `SmoothPlastic` | `true` | `0` |
| 31 | | `CloudNE_Top` | `Ball` | `7.5, 6, 7.5` | `328, 7.5, -52` | `0, 0, 0` | `145, 220, 255` | `SmoothPlastic` | `true` | `0` |
| 32 | **4. Nuvem Agrupada SE (4 Balls)** | `CloudSE_Center` | `Ball` | `13, 8.5, 10` | `328, 4.2, 52` | `0, 0, 0` | `145, 220, 255` | `SmoothPlastic` | `true` | `0` |
| 33 | | `CloudSE_Left` | `Ball` | `8.5, 6, 8` | `321, 3.0, 50` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `true` | `0` |
| 34 | | `CloudSE_Right` | `Ball` | `9, 6.5, 8.5` | `335, 3.2, 51` | `0, 0, 0` | `255, 182, 213` | `SmoothPlastic` | `true` | `0` |
| 35 | | `CloudSE_Top` | `Ball` | `7.5, 6, 7.5` | `328, 7.5, 52` | `0, 0, 0` | `185, 130, 255` | `SmoothPlastic` | `true` | `0` |
| 36 | **5. Arco-Íris Leste (7 Parts)** | `RainbowBaseNorth` | `Ball` | `9, 6, 9` | `342, 3.0, -24` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `true` | `0` |
| 37 | | `RainbowBaseSouth` | `Ball` | `9, 6, 9` | `342, 3.0, 24` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `true` | `0` |
| 38 | | `RainbowSegNorthLow` | `Block` | `2.5, 14, 3.5` | `342, 9.0, -20` | `-22, 0, 0` | `255, 95, 162` | `SmoothPlastic` | `true` | `0` |
| 39 | | `RainbowSegNorthMid` | `Block` | `2.5, 14, 3.5` | `342, 18.5, -11.5` | `-52, 0, 0` | `185, 130, 255` | `SmoothPlastic` | `true` | `0` |
| 40 | | `RainbowSegTop` | `Block` | `2.5, 3.5, 14` | `342, 22.5, 0` | `0, 0, 0` | `255, 230, 95` | `Neon` | `true` | `0` |
| 41 | | `RainbowSegSouthMid` | `Block` | `2.5, 14, 3.5` | `342, 18.5, 11.5` | `52, 0, 0` | `145, 220, 255` | `SmoothPlastic` | `true` | `0` |
| 42 | | `RainbowSegSouthLow` | `Block` | `2.5, 14, 3.5` | `342, 9.0, 20` | `22, 0, 0` | `255, 182, 213` | `SmoothPlastic` | `true` | `0` |
| 43 | **6. Cone de Algodão-Doce Sul (2 Parts)** | `CottonConeS_Stick` | `Cylinder` | `8, 2.2, 2.2` | `282, 4.0, 52` | `0, 0, 90` | `255, 245, 220` | `SmoothPlastic` | `true` | `0` |
| 44 | | `CottonConeS_Fluff` | `Ball` | `10, 12, 10` | `282, 11.5, 52` | `0, 0, 0` | `255, 182, 213` | `SmoothPlastic` | `true` | `0` |
| 45 | **7. Estrelas Neon Pequenas (6 Parts)** | `StarNeon_01` | `Block` | `2.2, 2.2, 2.2` | `236, 12.0, -52` | `45, 45, 0` | `255, 230, 95` | `Neon` | `false` | `0` |
| 46 | | `StarNeon_02` | `Block` | `2.2, 2.2, 2.2` | `236, 12.0, 52` | `45, 45, 0` | `145, 220, 255` | `Neon` | `false` | `0` |
| 47 | | `StarNeon_03` | `Block` | `2.4, 2.4, 2.4` | `282, 14.0, -52` | `45, 45, 0` | `255, 182, 213` | `Neon` | `false` | `0` |
| 48 | | `StarNeon_04` | `Block` | `2.4, 2.4, 2.4` | `282, 19.0, 52` | `45, 45, 0` | `255, 230, 95` | `Neon` | `false` | `0` |
| 49 | | `StarNeon_05` | `Block` | `2.2, 2.2, 2.2` | `328, 12.5, -52` | `45, 45, 0` | `185, 130, 255` | `Neon` | `false` | `0` |
| 50 | | `StarNeon_06` | `Block` | `2.2, 2.2, 2.2` | `328, 12.5, 52` | `45, 45, 0` | `255, 230, 95` | `Neon` | `false` | `0` |

---

## 8. Resumo da Contagem Total de Parts (`Workspace.Areas.CottonClouds`)

| Subpasta / Objeto | Quantidade de Parts | Observações |
|---|---:|---|
| `Bounds` | `1` | `Size = (139, 480, 140)` em `(282.5, 160, 0)` (`X ∈ [213, 352]`, `Y ∈ [-80, 400]`, `Z ∈ [-70, 70]`) |
| `SpawnLocation` | `1` | Em `(230, 0.5, 0)`, `Enabled = false`, `Neutral = true` |
| `BlockSpawns` | `10` | 6 `"CloudBlock"` + 4 `"ChocoBlock"`, invisíveis (`Size = (1, 1, 1)` em `Y = 3`) |
| `Gate` | `5` | `Model` em `X = 212, Z ∈ [-8, 8]`, `PrimaryPart = Core` (`Y = 4.5`) + 4 peças |
| `Eggs` | `0` | Pasta vazia (ovo da Área 3 fica para depois) |
| `Scenery` | `50` | 19 estruturais + 31 enfeites (4 nuvens de 4 `Ball`, arco-íris de 7 `Parts`, algodão-doce de 2 `Parts`, 6 estrelas `Neon`) |
| **Total Geral (`CottonClouds`)** | **67** | Leve para dispositivos móveis (cenário ≤ 60 Parts) |

## Ajustes da revisão (A7)

- `EntranceBridge` com `Size = (16, 0.2, 16)` (cobre `Z ∈ [-8, 8]`, sem fresta nos lados do portão).
- `Bounds` começa em `X = 213` (`Size = (139, 480, 140)`, `Position = (282.5, 160, 0)`), logo depois do `Gate`; os pilares da cascata ocupam de fato `X ∈ [207.25, 210.75]`.
- Arco-íris sem z-fighting: `Size.X` dos segmentos `2.50, 2.54, 2.58, 2.54, 2.50` (norte baixo, norte meio, topo, sul meio, sul baixo).
