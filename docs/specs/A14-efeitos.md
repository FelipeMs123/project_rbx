# Spec A14: Efeitos visuais de quebra de bloco (Squad A)

**Tarefa:** ROADMAP Fase 3 — A14 Efeitos (parte Squad A).
**Dono:** Squad A (`@FelipeMs123`).
**Fora de escopo:** rastro dos pets (`PetController.luau` pertence à Squad B / `@drkk71`; vai como recado no branch `diario` / `recados.md`). Nenhum som novo, nenhum Remote novo, nenhuma mudança de contrato.

---

## 1. Objetivo e princípios

Dar feedback visual satisfatório ao quebrar blocos de doce sem prejudicar a leitura da tela nem a performance em dispositivos móveis:
- **Cliente só desenha:** quantidades e valores vêm exclusivamente dos eventos do servidor já existentes (`BlockBroken` e `Notify("REWARD", ...)`).
- **Duração curta (`< 1 s`):** todos os efeitos terminam em menos de 1 segundo.
- **Limite simultâneo:** teto de bursts de partículas/brilho e de textos flutuantes ativos ao mesmo tempo, evitando queda de FPS e poluição visual.
- **Não cobrir HUD nem bloquear toque:** `ScreenGui` próprio (`CandyEffects`) com `DisplayOrder = -1` (abaixo do `CandyHud` = `0`, da HUD A13 e do `CandyToasts` = `100`) e `Active = false` em todos os elementos; Parts de efeito no mundo com `Anchored = true`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false`, `CastShadow = false`.

---

## 2. Eventos e mapeamento de efeitos

| Evento (Servidor → Cliente) | Payload já existente | Efeito disparado | Onde ocorre |
|---|---|---|---|
| `BlockBroken` | `blockId: string, position: Vector3, blockType: string` | **Confete** + **Brilho ao quebrar** | Na `position` do bloco (se dentro de `EffectsRadius` / visível pela câmera) |
| `Notify` (`code == "REWARD"`) | `{ coins: number, gems: number, blockId: string?, blockType: string? }` | **"+N moedas" voando** (e "+M gemas" se `gems > 0`) | Apenas quando `blockId ~= nil` (recompensa de bloco; diária não dispara). Projeta a última posição conhecida do `blockId` para a tela (fallback no centro inferior seguro se fora da câmera/sem posição) e sobe suavemente com fade out |

> **Nota sobre posição do `REWARD`:** `BlockController` já acompanha os modelos em `Workspace.Blocks` e recebe `BlockBroken`. Manter um cache leve e com TTL curto (`blockId -> position`) preenchido na entrada/remoção do modelo e no `BlockBroken` permite posicionar o `"+N moedas"` na posição exata do bloco mesmo que `Notify` chegue antes ou depois de `BlockBroken` ou da destruição do `Model`.

---

## 3. Detalhamento dos três efeitos

### 3.1 Confete (`BlockBroken`)
- **Visual:** `ParticleEmitter` emitindo rajada única (`Rate = 0`, `Emit(count)`) com partículas coloridas de doce (paleta configurável em `Config/Effects`, com variação por `blockType` ou mistura festiva de rosa, amarelo, azul-algodão e menta).
- **Movimento:** `SpreadAngle = Vector2.new(180, 180)`, velocidade inicial moderada, gravidade suave (`Acceleration` negativa em Y) e rotação (`RotSpeed`) para parecer confete caindo.
- **Duração:** `Lifetime` máximo `<= 0.8 s`; `Debris:AddItem` no anchor em `<= 0.95 s`.
- **Limite:** respeitar `MaxActiveBursts` (descartar ou ignorar novos bursts se atingir o teto).

### 3.2 Brilho ao quebrar (`BlockBroken`)
- **Visual:** pulso luminoso curto na `position` do bloco:
  - Uma esfera/partícula radial translúcida (ou `BillboardGui` com gradiente/ícone radial branco-dourado) que expande rapidamente e faz fade out (`Transparency -> 1`), opcionalmente combinada com `PointLight` de alcance curto que reduz `Brightness` a `0`.
- **Duração:** `<= 0.45 s` (tween `Quad`/`Out`), limpa junto com o anchor (`< 1 s`).
- **Limite:** compartilha o mesmo controle de `MaxActiveBursts` para não acumular luzes dinâmicas no mobile.

### 3.3 "+N moedas" voando (`Notify("REWARD")` com `blockId`)
- **Visual:** `TextLabel` em `ScreenGui` `CandyEffects` (`DisplayOrder = -1`, `IgnoreGuiInset = false`, `ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets`, `Active = false`).
- **Texto:** `"+{Format.abbreviate(coins)} moedas"` em dourado (`Color3.fromRGB(255, 220, 80)`) com contorno escuro para leitura sobre qualquer fundo. Se `gems > 0`, incluir na mesma linha ou logo abaixo `"+{Format.abbreviate(gems)} gemas"` em ciano (`Color3.fromRGB(100, 225, 255)`). Se `coins == 0` e `gems == 0`, não desenhar.
- **Animação:** nasce na projeção de tela da `position` do bloco (com leve jitter horizontal aleatório configurado para múltiplos ganhos não empilharem exatamente no mesmo pixel), sobe em `Y` (tween `0.75 s`, `Cubic`/`Out`) e faz fade out nos últimos instantes (`TextTransparency = 1`, `TextStrokeTransparency = 1`), destruindo o label ao terminar.
- **Limite:** máximo `MaxActiveFloatingRewards` simultâneos (se atingir o teto, remove o mais antigo antes de criar o novo).

---

## 4. Balanceamento em `src/shared/Config/`

Criar `src/shared/Config/Effects.luau` (`--!strict`, `Dono: Squad A.`, `table.freeze`), sem números mágicos espalhados no código:
- **Limites:**
  - `MaxActiveBursts = 8`
  - `MaxActiveFloatingRewards = 10`
  - `PositionCacheTtlSeconds = 3`
- **Confete:**
  - `ConfettiCount = 24`
  - `ConfettiLifetimeMin = 0.4`, `ConfettiLifetimeMax = 0.75`
  - `ConfettiSpeedMin = 6`, `ConfettiSpeedMax = 14`
  - `ConfettiGravityY = -18`
  - `ConfettiColors` (lista/paleta de `Color3` de doce)
- **Brilho:**
  - `GlowDuration = 0.35`
  - `GlowStartSize = 2`, `GlowEndSize = 9`
  - `GlowLightRange = 14`, `GlowLightBrightness = 2.5`
- **"+N moedas" voando:**
  - `RewardFlyDuration = 0.75`
  - `RewardRisePixels = 70`
  - `RewardJitterPixels = 18`
  - `AnchorLifetime = 0.9` (`< 1 s`)

---

## 5. Arquivos envolvidos (Squad A)

- `src/shared/Config/Effects.luau` (novo — constantes visuais e limites)
- `src/client/UI/Effects/BlockEffects.luau` (novo — renderização de confete, brilho e "+N moedas" voando)
- `src/client/Controllers/BlockController.luau` (edição — cache de posição por `blockId`, chamada a `BlockEffects` em `BlockBroken` e `Notify("REWARD")`)

---

## 6. Critérios de aceite

1. Ao quebrar qualquer bloco (`BlockBroken`), aparecem **confete** colorido e **brilho** rápido na posição do bloco.
2. Ao receber recompensa de bloco (`Notify("REWARD")` com `blockId`), aparece **"+N moedas" voando** (e gemas quando `gems > 0`) com o valor exato enviado pelo servidor, formatado via `Format.abbreviate`.
3. Recompensa sem `blockId` (ex.: diária) **não** dispara "+N moedas" voando de bloco.
4. Todos os efeitos duram **menos de 1 segundo** e respeitam os limites simultâneos definidos em `Config/Effects.luau`.
5. `CandyEffects` usa `DisplayOrder = -1` e `Active = false`, não cobrindo `CandyHud`, `CandyToasts` (`DisplayOrder = 100`) nem bloqueando cliques/toques.
6. Nenhum som novo adicionado; `PetController.luau`, `Remotes.luau` e `CONTRATO.md` intactos.
7. `lune run check` termina com `TUDO OK`.

---

## 7. Como testar no Roblox Studio

1. Conectar o Studio via `rojo serve` no worktree da tarefa (`a/a14`) e iniciar Play Solo (ou servidor local).
2. Aproximar o personagem de um bloco em `CandyPlaza` e bater até zerar o HP:
   - **Esperado:** ao quebrar, surge o **brilho** rápido e o **confete** colorido na posição do bloco, e o texto **"+N moedas"** (com o mesmo valor creditado no saldo) sobe e desaparece em menos de 1 segundo.
3. Quebrar vários blocos em sequência rápida:
   - **Esperado:** efeitos permanecem fluidos, não acumulam instâncias presas em `Workspace` ou `PlayerGui.CandyEffects`, e não cobrem saldos nem toasts.
4. Testar em emulação de tela mobile (Device Emulator no Studio):
   - **Esperado:** "+N moedas" legível, sem bloquear toques nos blocos ou botões.
