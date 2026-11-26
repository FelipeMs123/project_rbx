# HUD A13 — integração e validação

Dono: Squad A. `HudController` orquestra `TopBar`, `SideMenu`, `BottomBar` e `Theme`.
`Config/UIIcons` reserva IDs vazios para a futura arte; o HUD usa emojis e formas nativas enquanto isso.

## Layout e rótulos (inglês)

- **TopBar**: cápsulas `Coins` (disco dourado nativo, valor amarelo, botão `+`) e `Gems` (`💎`, valor azul, botão `+`). No PC e retrato fica no topo central; em paisagem compacta encosta no topo à direita (`topY = 6`, ou abaixo do tutorial quando `topReserve > 0`).
- **SideMenu**: grade de 2 colunas na borda esquerda, no meio da altura — linha 1: `DAILY` (`DailyButton`, bolinha vermelha `DailyBadge` no canto superior direito quando há recompensa), `SHOP` (`ShopButton`); linha 2: `PETS` (`PetsButton`), `BACKPACK` (`InventoryButton`); linha 3: `SETTINGS` (`SettingsButton`, coluna da esquerda). Em paisagem compacta fica abaixo dos botões do Roblox e acima do analógico inferior esquerdo, com margem esquerda segura.
- **RebirthBadge**: selo `Rebirth [N]` roxo escuro alinhado à borda direita segura, no meio da altura, acima da `BottomBar`/toasts. Começa escondido (`Visible = false`) e passa a aparecer depois que `RebirthUI` registra `"Rebirth"` no `MenuCoordinator` e esconde o `RebirthToggleButton` (`Visible = false`); enquanto o botão roxo estiver `Visible = false`, o `HudController` o ignora no layout (sem reserva de espaço) e reaplica o layout caso `Visible` mude. Possui a bolinha verde `ReadyDot` (18 px, canto superior direito, invisível por padrão) que espelha `ReadyBadge.Visible` do `RebirthToggleButton`.
- **BottomBar**: `AUTO-CLICK` (`AutoClick`, `🖱️`) e `x3 EGGS` (`TripleEggs`, `🥚`) centralizados na parte inferior, sem selo de Robux.
- **Toasts**: `"Shop coming soon!"` (SHOP e botões `+`), `"Coming soon!"` (`AUTO-CLICK` e `x3 EGGS`) e `"+N coins"` / `"+N coins · +M gems"` (recompensas). Em retrato, quando a pilha cruza a faixa vertical do `RebirthToggleButton`, a largura é reduzida para terminar `>= 8 px` à esquerda dele (mínimo 160 px). Nota: nomes de área em português (ex.: `"Cascata de Chocolate"` vindo de `Config/Areas.luau` em `Messages.luau`) ficam para a rodada de textos (`PR a/textos-en`).

## Integração com os painéis

- O HUD não importa UI/Rebirth, UI/Pets, UI/Eggs nem seus Controllers.
  TopBar, SideMenu e BottomBar importam somente Theme; Theme e MenuCoordinator não têm requires.
- `MenuCoordinator` coordena `Pets`, `Rebirth`, `Daily`, `Settings` e `Eggs`, fechando os
  demais modais ao abrir um deles (inclusive `FusionConfirmOverlay` ao sair de Pets).
- `PETS` e `BACKPACK` (`PetsButton` / `InventoryButton`) abrem `PetsModal` diretamente (`Visible = true`) e escondem
  `PetsToggleButton`. A grade de pets já se recalcula automaticamente sem chamar
  `openBtn.Activated`, pois em `src/client/UI/Pets/PetInventoryUI.luau`:
  - `scrolling:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateGridLayout)` (linha 1425)
    recalcula `FillDirectionMaxCells`, `CellPadding` e `CellSize` sempre que o `AbsoluteSize`
    do `PetGrid` muda (inclusive ao montar/exibir o modal);
  - `updateResponsiveScale()` (linhas 386-402) chama `updateGridLayout()` no `Mount()` (linha 1612)
    e em toda mudança de `ViewportSize` (linha 1599);
  - `updateGridLayout()` (linhas 260-287) depende apenas de `uiScale.Scale`, `grid.AbsoluteSize.X`
    e `isCompactViewport`.
- O selo `Rebirth [N]` usa `MenuCoordinator.Open("Rebirth")`. `RebirthUI` agora registra `RebirthUI.SetModalOpen` via `MenuCoordinator.Register("Rebirth", RebirthUI.SetModalOpen)` no `Mount()` (removendo o registro em `Destroy()`/desmontagem) e esconde o botão roxo `RebirthToggleButton` (`Visible = false`), deixando o selo `Rebirth [N]` como único acesso ao Rebirth. Enquanto não há setter registrado, `top.Rebirth` fica escondido (`Visible = false`, observado via `MenuCoordinator.SetRebirthRegisteredObserver`).
- `SETTINGS` (`SettingsButton`) abre `SoundSettings.ModalOverlay` e esconde `OpenSettings`.
  `DAILY` (`DailyButton`) abre `DailyRewards.ModalOverlay` e esconde `OpenDaily`, espelhando
  `AvailableBadge` na bolinha vermelha `DailyBadge` no canto superior direito do botão.
- Start espera PlayerGui por no máximo 10 s. Os cliques procuram as instâncias
  novamente, sem espera; se Pets/Rebirth ainda não existe, exibem aviso para tentar novamente.
- `SetTopReserve` reposiciona o topo e os avisos abaixo da faixa do tutorial.
  `CandyToasts` mantém DisplayOrder 100.
- Nas telas baixas (`compact`, `ViewportSize.Y - GuiService:GetGuiInset().Y < 440`, ex.: 667x375, 750x381 e 844x390), `CandyHud` e
  `CandyToasts` usam `DeviceSafeInsets`.

## Como testar no Studio (humano/líder)

1. Conectar Rojo nesta cópia e iniciar Play no PC (1316x573). Conferir saldos abreviados,
   menu lateral em grade 2 colunas à esquerda (`DAILY`, `SHOP`, `PETS`, `BACKPACK`, `SETTINGS`),
   `AUTO-CLICK` / `x3 EGGS` no rodapé e selo `Rebirth [N]` visível à direita (com `RebirthToggleButton` escondido pela `RebirthUI`), abrindo o modal de Rebirth pelo fluxo original.
2. Clicar `SHOP` e nos dois `+`: `"Shop coming soon!"`. Clicar `AUTO-CLICK` e `x3 EGGS`:
   `"Coming soon!"`. Abrir um modal e conferir avisos acima dele.
3. Clicar `PETS` e `BACKPACK`; conferir grade, equipar/desequipar, abas e fechar.
   Clicar `SETTINGS` e alterar música/sons. Clicar `DAILY` e conferir bolinha vermelha quando houver recompensa.
4. Usar perfil novo para conferir faixa e destaque do tutorial: faixa, topo e
   grade não podem se cruzar. O destaque de equipar deve cercar `PetsButton`.
5. Emular 844x390, 750x381, 667x375 e retrato 401x778, girando durante Play. Conferir
   botões do Roblox, notch, analógico, pulo, `RebirthToggleButton` e rodapé sem sobreposição;
   medir `AbsoluteSize` dos botões (mínimo 44 px reais). Conferir com tutorial ativo/inativo.
6. Conferir Output sem erros. O líder roda `lune run check` e formatação.

Não houve teste no Studio nem execução de lune/stylua pelo worker.
Loja, auto-click, ovos triplos e imagens finais continuam fora desta tarefa.
