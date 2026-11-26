# Spec A12: Decoração 3D das 3 Áreas (`CandyPlaza`, `ChocolateFalls`, `CottonClouds`)

**Tarefa:** A12 (`docs/ROADMAP.md`, Fase 3)  
**Executor:** Arte e Mapa (primeira passada por código via `tools/map/*.luau` → `tools/map/build.luau` → `assets/map/*.model.json`)  
**Restrições da passada:** sem `generate_mesh`, sem asset publicado na conta do dono, sem Blender. Apenas Parts nativas (`Block`, `Ball`, `Cylinder`).

---

## 1. Regras Gerais de Geometria e Segurança

1. **Ancoragem e Colisão:**
   - Todas as Parts são ancoradas (`Anchored = true`, aplicado automaticamente por `tools/map/build.luau`).
   - Todo enfeite atravessável, viga/arco aéreo e granulado no chão deve ter `CanCollide = false`, `CanQuery = false`, `CanTouch = false` (não trava o jogador e não intercepta cliques/raycasts em Lucky Blocks).
   - Morros de doce nas bordas externas têm `CanCollide = true` e `CanQuery = false` (ou padrão, pois ficam longe de blocos).
2. **Z-fighting no piso:**
   - Em todas as 3 áreas, o topo de `BaseFloor` fica em `Y = 0.1`.
   - Todo granulado decorativo no chão (`Sprinkle_*`) fica em `Position.Y = 0.2` com `Size.Y = 0.1` (acima de `Y = 0.1`, sem z-fighting).
3. **Formato Rojo 7 (`.model.json`):**
   - `CFrame` sempre com tipo explícito e chave `"attributes"` em minúsculo (garantido por `tools/map/build.luau`).
   - Nenhum atributo ou estrutura usada pela Squad B (`Eggs`, `Gate`, `BlockSpawns`, `Bounds`) é alterada.
4. **CODEOWNERS:**
   - `assets/map/CandyPlaza.model.json` e `tools/map/` são da Squad A (`@FelipeMs123`).
   - `assets/map/ChocolateFalls.model.json` e `assets/map/CottonClouds.model.json` caem na regra `*` (`@FelipeMs123 @drkk71`), portanto o PR final deve pedir review da Squad B.

---

## 2. Orçamento de Parts (Teto: 120 Parts por área)

| Área | `Scenery` atual | Novas Parts | `Scenery` final | Outras Parts (`Bounds`, `SpawnLocation`, `BlockSpawns`, `Gate`, `Eggs`) | Total na Área | Teto |
|---|---:|---:|---:|---:|---:|---:|
| `CandyPlaza` | 54 | +26 | **80** | 19 (1 + 10 + 8) | **99** | 120 |
| `ChocolateFalls` | 47 | +25 | **72** | 25 (1 + 1 + 10 + 5 + 8) | **97** | 120 |
| `CottonClouds` | 50 | +24 | **74** | 17 (1 + 1 + 10 + 5 + 0) | **91** | 120 |

---

## 3. O que NÃO pode ser bloqueado (Zonas Livres Obrigatórias)

- **`SpawnLocation`:**
  - `CandyPlaza`: `(-18, 0.5, 0)` (raio livre ≥ 8 studs)
  - `ChocolateFalls`: `(122, 0.5, 0)` (raio livre ≥ 8 studs)
  - `CottonClouds`: `(230, 0.5, 0)` (raio livre ≥ 8 studs)
- **`BlockSpawns`:** todas as 10 posições de cada área (raio livre ≥ 6 studs ao redor de cada spawn).
- **Pedestais e `Eggs`:**
  - `CandyPlaza`: `(0, 0, -28)` (raio livre 10 studs)
  - `ChocolateFalls`: `(140, 0, -28)` (raio livre 10 studs)
  - `CottonClouds`: `(282, 0, -28)` (raio livre 10 studs)
- **Passagens e `Gate`s:**
  - Passagem `CandyPlaza` → `ChocolateFalls`: `X ∈ [68, 72]`, `Z ∈ [-8, 8]`, `Y ∈ [0, 10.5]` totalmente livre; `ChocolateFalls.Gate` em `X = 70.6` intocado.
  - Passagem `ChocolateFalls` → `CottonClouds`: `X ∈ [208, 213]`, `Z ∈ [-8, 8]`, `Y ∈ [0, 10.5]` totalmente livre; `CottonClouds.Gate` em `X = 212` intocado.
- **Caminhos principais:** `PathEastWest` / `PathWestEast` (`Z ∈ [-7, 7]`), `PathNorth`, `PathSouth`, `EntranceBridge` e discos centrais totalmente livres de obstáculos colidíveis.

---

## 4. Peças por Área

### 4.1. `CandyPlaza` (`tools/map/CandyPlaza.luau`) — +26 Parts (`Scenery`: 54 → 80)

#### A. Arco "Candy Plaza" (7 Parts, `X = -10`, sobre `PathEastWest`)
Pilares fora do corredor `Z ∈ [-7, 7]` (`Z = ±9.5`); viga e topo em `Y ≥ 12` com `CanCollide = false`, `CanQuery = false`, `CanTouch = false`.

| Nome | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Rotation | Color `(R, G, B)` | Material | `CanCollide` |
|---|---|---|---|---|---|---|---|
| `PlazaArch_PillarN` | `Cylinder` | `12, 2.4, 2.4` | `-10, 6, -9.5` | `0, 0, 90` | `255, 95, 162` | `SmoothPlastic` | `true` |
| `PlazaArch_PillarS` | `Cylinder` | `12, 2.4, 2.4` | `-10, 6, 9.5` | `0, 0, 90` | `255, 95, 162` | `SmoothPlastic` | `true` |
| `PlazaArch_CapN` | `Ball` | `3.2, 3.2, 3.2` | `-10, 12.2, -9.5` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `PlazaArch_CapS` | `Ball` | `3.2, 3.2, 3.2` | `-10, 12.2, 9.5` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `PlazaArch_Beam` | `Block` | `2, 2.4, 20` | `-10, 12.8, 0` | `0, 0, 0` | `255, 245, 220` | `SmoothPlastic` | `false` |
| `PlazaArch_Crest` | `Block` | `2.2, 1.6, 12` | `-10, 14.4, 0` | `0, 0, 0` | `115, 215, 255` | `SmoothPlastic` | `false` |
| `PlazaArch_Star` | `Block` | `2.2, 2.2, 2.2` | `-10, 16.2, 0` | `45, 45, 0` | `255, 230, 95` | `Neon` | `false` |

*(Todas as peças com `CanCollide = false` acima também levam `CanQuery = false, CanTouch = false`.)*

#### B. Portão de Biscoito (5 Parts, `X = 69`, emoldurando a passagem para `ChocolateFalls`)
Fica acima de `Y = 11` e nas laterais `Z = ±9.75` (sem bloquear `Z ∈ [-8, 8], Y ∈ [0, 10.5]` e sem encostar em `ChocolateFalls.Gate` em `X = 70.6`). Todas com `CanCollide = false`, `CanQuery = false`, `CanTouch = false`.

| Nome | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Rotation | Color `(R, G, B)` | Material |
|---|---|---|---|---|---|---|
| `CookieGate_Lintel` | `Block` | `2.4, 2.2, 21` | `69, 12.2, 0` | `0, 0, 0` | `240, 195, 135` | `SmoothPlastic` |
| `CookieGate_IcingTop` | `Block` | `2.6, 0.8, 21.4` | `69, 13.5, 0` | `0, 0, 0` | `255, 95, 162` | `SmoothPlastic` |
| `CookieGate_CookieN` | `Cylinder` | `1.2, 4.8, 4.8` | `69, 9.2, -9.75` | `0, 0, 0` | `240, 195, 135` | `SmoothPlastic` |
| `CookieGate_CookieS` | `Cylinder` | `1.2, 4.8, 4.8` | `69, 9.2, 9.75` | `0, 0, 0` | `240, 195, 135` | `SmoothPlastic` |
| `CookieGate_ChocoChipC` | `Ball` | `2.0, 2.0, 2.0` | `69, 12.2, 0` | `0, 0, 0` | `75, 40, 22` | `SmoothPlastic` |

#### C. Morros de Doce (6 Parts = 3 morros × 2 Parts, nas bordas livres)
Bases com `CanCollide = true`; coberturas (`Top`) com `CanCollide = false`, `CanQuery = false`, `CanTouch = false`.

| Nome | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Rotation | Color `(R, G, B)` | Material | `CanCollide` |
|---|---|---|---|---|---|---|---|
| `CandyHillNW_Base` | `Ball` | `18, 10, 18` | `-56, 2, -26` | `0, 0, 0` | `255, 182, 213` | `SmoothPlastic` | `true` |
| `CandyHillNW_Top` | `Ball` | `12, 6, 12` | `-56, 5.8, -26` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `CandyHillSW_Base` | `Ball` | `18, 10, 18` | `-56, 2, 26` | `0, 0, 0` | `120, 240, 180` | `SmoothPlastic` | `true` |
| `CandyHillSW_Top` | `Ball` | `12, 6, 12` | `-56, 5.8, 26` | `0, 0, 0` | `255, 245, 220` | `SmoothPlastic` | `false` |
| `CandyHillNE_Base` | `Ball` | `18, 10, 18` | `24, 2, -56` | `0, 0, 0` | `115, 215, 255` | `SmoothPlastic` | `true` |
| `CandyHillNE_Top` | `Ball` | `12, 6, 12` | `24, 5.8, -56` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |

#### D. Piso com Granulado (8 Parts, `Y = 0.2`)
Todas `Shape = "Block"`, `Size = { 1.8, 0.1, 0.7 }`, `Material = "SmoothPlastic"`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`.

| Nome | Position `(X, Y, Z)` | Rotation `(X, Y, Z)` | Color `(R, G, B)` |
|---|---|---|---|
| `Sprinkle_01` | `-32, 0.2, -16` | `0, 25, 0` | `255, 230, 95` |
| `Sprinkle_02` | `-34, 0.2, 16` | `0, -35, 0` | `120, 240, 180` |
| `Sprinkle_03` | `-12, 0.2, -36` | `0, 60, 0` | `115, 215, 255` |
| `Sprinkle_04` | `14, 0.2, -36` | `0, -20, 0` | `255, 95, 162` |
| `Sprinkle_05` | `20, 0.2, 34` | `0, 40, 0` | `255, 230, 95` |
| `Sprinkle_06` | `-14, 0.2, 34` | `0, -50, 0` | `185, 130, 255` |
| `Sprinkle_07` | `46, 0.2, -26` | `0, 15, 0` | `120, 240, 180` |
| `Sprinkle_08` | `46, 0.2, 26` | `0, -30, 0` | `255, 65, 90` |

---

### 4.2. `ChocolateFalls` (`tools/map/ChocolateFalls.luau`) — +25 Parts (`Scenery`: 47 → 72)

#### A. Portão de Biscoito Leste (5 Parts, `X = 209`, emoldurando a passagem para `CottonClouds`)
Acima de `Y = 11` e nas laterais `Z = ±9.75` (sem bloquear `Z ∈ [-8, 8], Y ∈ [0, 10.5]` e sem interferir em `CottonClouds.Gate` em `X = 212`). Todas com `CanCollide = false`, `CanQuery = false`, `CanTouch = false`.

| Nome | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Rotation | Color `(R, G, B)` | Material |
|---|---|---|---|---|---|---|
| `EastCookieGate_Lintel` | `Block` | `2.4, 2.2, 21` | `209, 12.2, 0` | `0, 0, 0` | `240, 195, 135` | `SmoothPlastic` |
| `EastCookieGate_Icing` | `Block` | `2.6, 0.8, 21.4` | `209, 13.5, 0` | `0, 0, 0` | `75, 40, 22` | `SmoothPlastic` |
| `EastCookieGate_CookieN` | `Cylinder` | `1.2, 4.8, 4.8` | `209, 9.2, -9.75` | `0, 0, 0` | `240, 195, 135` | `SmoothPlastic` |
| `EastCookieGate_CookieS` | `Cylinder` | `1.2, 4.8, 4.8` | `209, 9.2, 9.75` | `0, 0, 0` | `240, 195, 135` | `SmoothPlastic` |
| `EastCookieGate_CaramelGem` | `Ball` | `2.2, 2.2, 2.2` | `209, 12.2, 0` | `0, 0, 0` | `245, 185, 75` | `Neon` |

#### B. Morros de Doce de Cacau/Caramelo (8 Parts = 4 morros × 2 Parts, em `|Z| = 56`)
Bases com `CanCollide = true`; coberturas (`Top`) com `CanCollide = false`, `CanQuery = false`, `CanTouch = false`.

| Nome | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Rotation | Color `(R, G, B)` | Material | `CanCollide` |
|---|---|---|---|---|---|---|---|
| `ChocoHillNW_Base` | `Ball` | `16, 9, 16` | `106, 2, -56` | `0, 0, 0` | `75, 40, 22` | `SmoothPlastic` | `true` |
| `ChocoHillNW_Top` | `Ball` | `11, 5.5, 11` | `106, 5.4, -56` | `0, 0, 0` | `245, 185, 75` | `SmoothPlastic` | `false` |
| `ChocoHillNE_Base` | `Ball` | `16, 9, 16` | `172, 2, -56` | `0, 0, 0` | `120, 72, 42` | `SmoothPlastic` | `true` |
| `ChocoHillNE_Top` | `Ball` | `11, 5.5, 11` | `172, 5.4, -56` | `0, 0, 0` | `255, 245, 220` | `SmoothPlastic` | `false` |
| `ChocoHillSW_Base` | `Ball` | `16, 9, 16` | `106, 2, 56` | `0, 0, 0` | `120, 72, 42` | `SmoothPlastic` | `true` |
| `ChocoHillSW_Top` | `Ball` | `11, 5.5, 11` | `106, 5.4, 56` | `0, 0, 0` | `245, 185, 75` | `SmoothPlastic` | `false` |
| `ChocoHillSE_Base` | `Ball` | `16, 9, 16` | `172, 2, 56` | `0, 0, 0` | `75, 40, 22` | `SmoothPlastic` | `true` |
| `ChocoHillSE_Top` | `Ball` | `11, 5.5, 11` | `172, 5.4, 56` | `0, 0, 0` | `255, 245, 220` | `SmoothPlastic` | `false` |

#### C. Piso com Granulado (12 Parts, `Y = 0.2`)
Todas `Shape = "Block"`, `Size = { 1.8, 0.1, 0.7 }`, `Material = "SmoothPlastic"`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`.

| Nome | Position `(X, Y, Z)` | Rotation `(X, Y, Z)` | Color `(R, G, B)` |
|---|---|---|---|
| `Sprinkle_01` | `96, 0.2, -18` | `0, 20, 0` | `245, 185, 75` |
| `Sprinkle_02` | `96, 0.2, 18` | `0, -35, 0` | `255, 245, 220` |
| `Sprinkle_03` | `108, 0.2, -34` | `0, 50, 0` | `255, 95, 162` |
| `Sprinkle_04` | `108, 0.2, 34` | `0, -15, 0` | `245, 185, 75` |
| `Sprinkle_05` | `124, 0.2, -36` | `0, 30, 0` | `255, 245, 220` |
| `Sprinkle_06` | `156, 0.2, -36` | `0, -45, 0` | `255, 230, 95` |
| `Sprinkle_07` | `124, 0.2, 34` | `0, 65, 0` | `240, 195, 135` |
| `Sprinkle_08` | `156, 0.2, 34` | `0, -25, 0` | `245, 185, 75` |
| `Sprinkle_09` | `186, 0.2, -26` | `0, 15, 0` | `255, 245, 220` |
| `Sprinkle_10` | `186, 0.2, 26` | `0, -40, 0` | `255, 65, 90` |
| `Sprinkle_11` | `194, 0.2, -16` | `0, 35, 0` | `245, 185, 75` |
| `Sprinkle_12` | `194, 0.2, 16` | `0, -20, 0` | `255, 245, 220` |

---

### 4.3. `CottonClouds` (`tools/map/CottonClouds.luau`) — +24 Parts (`Scenery`: 50 → 74)

#### A. Arco Pastel de Boas-Vindas (6 Parts, `X = 246`, sobre `PathWestEast`)
Pilares em `Z = ±9.5` (fora de `PathWestEast` `Z ∈ [-7, 7]`), viga e enfeites em `Y ≥ 12` com `CanCollide = false`, `CanQuery = false`, `CanTouch = false`.

| Nome | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Rotation | Color `(R, G, B)` | Material | `CanCollide` |
|---|---|---|---|---|---|---|---|
| `CloudArch_PillarN` | `Cylinder` | `12, 2.4, 2.4` | `246, 6, -9.5` | `0, 0, 90` | `185, 130, 255` | `SmoothPlastic` | `true` |
| `CloudArch_PillarS` | `Cylinder` | `12, 2.4, 2.4` | `246, 6, 9.5` | `0, 0, 90` | `185, 130, 255` | `SmoothPlastic` | `true` |
| `CloudArch_Beam` | `Block` | `2, 2.2, 20` | `246, 12.5, 0` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `CloudArch_PuffN` | `Ball` | `4.2, 3.6, 4.2` | `246, 12.6, -9.5` | `0, 0, 0` | `255, 182, 213` | `SmoothPlastic` | `false` |
| `CloudArch_PuffS` | `Ball` | `4.2, 3.6, 4.2` | `246, 12.6, 9.5` | `0, 0, 0` | `145, 220, 255` | `SmoothPlastic` | `false` |
| `CloudArch_StarTop` | `Block` | `2.4, 2.4, 2.4` | `246, 15.0, 0` | `45, 45, 0` | `255, 230, 95` | `Neon` | `false` |

#### B. Morros de Algodão-Doce (8 Parts = 4 morros × 2 Parts, em `|Z| = 56`)
Bases com `CanCollide = true`; coberturas (`Top`) com `CanCollide = false`, `CanQuery = false`, `CanTouch = false`.

| Nome | Shape | Size `(X, Y, Z)` | Position `(X, Y, Z)` | Rotation | Color `(R, G, B)` | Material | `CanCollide` |
|---|---|---|---|---|---|---|---|
| `CottonHillNW_Base` | `Ball` | `16, 9, 16` | `260, 2, -56` | `0, 0, 0` | `255, 182, 213` | `SmoothPlastic` | `true` |
| `CottonHillNW_Top` | `Ball` | `11, 5.5, 11` | `260, 5.4, -56` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `CottonHillNE_Base` | `Ball` | `16, 9, 16` | `304, 2, -56` | `0, 0, 0` | `145, 220, 255` | `SmoothPlastic` | `true` |
| `CottonHillNE_Top` | `Ball` | `11, 5.5, 11` | `304, 5.4, -56` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `CottonHillSW_Base` | `Ball` | `16, 9, 16` | `260, 2, 56` | `0, 0, 0` | `185, 130, 255` | `SmoothPlastic` | `true` |
| `CottonHillSW_Top` | `Ball` | `11, 5.5, 11` | `260, 5.4, 56` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |
| `CottonHillSE_Base` | `Ball` | `16, 9, 16` | `304, 2, 56` | `0, 0, 0` | `255, 182, 213` | `SmoothPlastic` | `true` |
| `CottonHillSE_Top` | `Ball` | `11, 5.5, 11` | `304, 5.4, 56` | `0, 0, 0` | `255, 255, 255` | `SmoothPlastic` | `false` |

#### C. Piso com Granulado Pastel (10 Parts, `Y = 0.2`)
Todas `Shape = "Block"`, `Size = { 1.8, 0.1, 0.7 }`, `Material = "SmoothPlastic"`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`.

| Nome | Position `(X, Y, Z)` | Rotation `(X, Y, Z)` | Color `(R, G, B)` |
|---|---|---|---|
| `Sprinkle_01` | `234, 0.2, -24` | `0, 25, 0` | `255, 182, 213` |
| `Sprinkle_02` | `234, 0.2, 24` | `0, -30, 0` | `145, 220, 255` |
| `Sprinkle_03` | `258, 0.2, -34` | `0, 50, 0` | `255, 230, 95` |
| `Sprinkle_04` | `258, 0.2, 34` | `0, -20, 0` | `185, 130, 255` |
| `Sprinkle_05` | `298, 0.2, -34` | `0, 35, 0` | `255, 95, 162` |
| `Sprinkle_06` | `298, 0.2, 34` | `0, -45, 0` | `145, 220, 255` |
| `Sprinkle_07` | `322, 0.2, -36` | `0, 15, 0` | `255, 230, 95` |
| `Sprinkle_08` | `322, 0.2, 36` | `0, -35, 0` | `255, 182, 213` |
| `Sprinkle_09` | `338, 0.2, -34` | `0, 60, 0` | `185, 130, 255` |
| `Sprinkle_10` | `338, 0.2, 34` | `0, -25, 0` | `255, 255, 255` |

---

## 5. Geração dos `.model.json` (`tools/map/build.luau`)

1. Atualizar as 3 asserções de contagem de `Scenery` em `tools/map/build.luau`:
   - `#plaza.Scenery == 80`
   - `#falls.Scenery == 72`
   - `#clouds.Scenery == 74`
2. Atualizar o `print` final com as novas contagens.
3. Rodar na raiz do worktree `D:\Sites\project_rbx-a12`:
   ```text
   lune run tools/map/build
   ```
   *(Se o sandbox bloquear com "home directory not found", rodar com `-s danger-full-access`.)*
4. O comando regenera `assets/map/CandyPlaza.model.json`, `assets/map/ChocolateFalls.model.json` e `assets/map/CottonClouds.model.json`.

---

## 6. Critérios de Aceite

1. `lune run tools/map/build` termina sem erro e regenera os 3 `.model.json`.
2. Contagem de `Scenery` e total de Parts por área dentro do orçamento (`80 / 99`, `72 / 97`, `74 / 91`, todos `< 120`).
3. Todas as peças decorativas atravessáveis e granulados têm `CanCollide = false`, `CanQuery = false`, `CanTouch = false`.
4. Granulados estão em `Y = 0.2` (sem z-fighting com `BaseFloor` em `Y = 0.1`).
5. Nenhum `SpawnLocation`, `BlockSpawn`, pedestal/ovo, `Gate` ou corredor de passagem (`Z ∈ [-8, 8]`) está obstruído.
6. `lune run check` no worktree termina em `TUDO OK`.

---

## 7. Como Testar no Studio

1. Iniciar `rojo serve` na raiz de `D:\Sites\project_rbx-a12` e conectar o Roblox Studio.
2. Dar Play e conferir visualmente a `CandyPlaza`: arco "Candy Plaza" à frente do spawn, portão de biscoito sobre a passagem leste, morros de doce nas bordas e granulado no piso rosa sem piscar (z-fighting).
3. Caminhar pelo corredor central até `ChocolateFalls` e depois `CottonClouds`, confirmando que o jogador passa livremente pelos arcos e portões, consegue clicar em todos os Lucky Blocks (`BlockSpawns`) sem que o granulado bloqueie o clique, e consegue se aproximar dos ovos (`CandyEgg`, `ChocolateEgg`).
4. Verificar no Output que não há erros e confirmar que `Gate`s e `Eggs` continuam funcionando normalmente.
