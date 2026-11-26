# HUD A13 — integração e validação

Dono: Squad A. `HudController` orquestra `TopBar`, `SideMenu`, `BottomBar` e `Theme`.
`Config/UIIcons` reserva IDs vazios para a futura arte; o HUD usa emojis enquanto isso.

## Integração com os painéis

- O HUD não importa UI/Rebirth, UI/Pets, UI/Eggs nem seus Controllers.
  TopBar, SideMenu e BottomBar importam somente Theme; Theme e MenuCoordinator não têm requires.
- `MenuCoordinator` coordena `Pets`, `Rebirth`, `Daily`, `Settings` e `Eggs`, fechando os
  demais modais ao abrir um deles (inclusive `FusionConfirmOverlay` ao sair de Pets).
- PETS e INVENTORY abrem `PetsModal` diretamente (`Visible = true`) e escondem
  `PetsToggleButton`. A grade de pets já se recalcula automaticamente sem chamar
  `openBtn.Activated`, pois em `src/client/UI/Pets/PetInventoryUI.luau`:
  - `scrolling:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateGridLayout)` (linha 1425)
    recalcula `FillDirectionMaxCells`, `CellPadding` e `CellSize` sempre que o `AbsoluteSize`
    do `PetGrid` muda (inclusive ao montar/exibir o modal);
  - `updateResponsiveScale()` (linhas 386-402) chama `updateGridLayout()` no `Mount()` (linha 1612)
    e em toda mudança de `ViewportSize` (linha 1599);
  - `updateGridLayout()` (linhas 260-287) depende apenas de `uiScale.Scale`, `grid.AbsoluteSize.X`
    e `isCompactViewport`.
- O selo Rebirth usa `MenuCoordinator.Open("Rebirth")`, que aguarda o registro de
  `RebirthUI.SetModalOpen` pela Squad B (ver `.alethe/a13-pendencias-squad-b.md`).
  Enquanto não há setter registrado, `RebirthToggleButton` permanece visível e o selo exibe
  aviso orientando a usá-lo.
- SETTINGS abre `SoundSettings.ModalOverlay` e esconde `OpenSettings`. A diária abre
  `DailyRewards.ModalOverlay` e esconde `OpenDaily`, espelhando `AvailableBadge` no botão
  diário do menu lateral.
- Start espera PlayerGui por no máximo 10 s. Os cliques procuram as instâncias
  novamente, sem espera; se Pets/Rebirth ainda não existe, exibem aviso para tentar novamente.
- `SetTopReserve` reposiciona o topo e os avisos abaixo da faixa do tutorial.
  `CandyToasts` mantém DisplayOrder 100.
- Nas telas baixas (`compact`, `ViewportSize.Y - GuiService:GetGuiInset().Y < 440`, ex.: 667x375 e 750x381), `CandyHud` e
  `CandyToasts` usam `DeviceSafeInsets`:
  - `TopBar` encosta no topo (`topY = 6`) alinhada à direita (`size.X - 12`) na mesma faixa
    vertical dos botões do Roblox, com largura limitada (`size.X - 262`) para deixar folga
    após os botões do canto superior esquerdo; se o tutorial estiver ativo (`topReserve > 0`),
    desce para `topInset + topReserve + 2` e limita a largura à esquerda de `RebirthToggleButton`
    (medido via `AbsolutePosition`/`AbsoluteSize` em `PlayerGui`, com fallback por fórmula).
  - `SideMenu` fica compacto e deslocado para dentro do analógico, mantendo `sideY` abaixo de
    `RebirthToggleButton` (`topInset + 0.37 * coreY + 8`).
  - `RebirthBadge` sai do centro e fica alinhado à direita (`size.X - 12`), logo abaixo do
    `SideMenu` (`sideY + 60 * sideFactor + 6`), mantendo o centro livre e sem sobrepor
    `RebirthToggleButton`, `BottomBar` ou os toasts.

## Como testar no Studio (humano/líder)

1. Conectar Rojo nesta cópia e iniciar Play no PC. Conferir saldos abreviados,
   selo Rebirth e ausência dos três atalhos antigos e presença do botão Pets. Quebrar blocos e conferir
   pop dos saldos e avisos de recompensa.
2. Clicar SHOP e nos dois +: “Loja em breve!”. Clicar AUTO-CLICK e x3 EGGS:
   “Disponível em breve!”. Abrir um modal e conferir avisos acima dele.
3. Clicar PETS e INVENTORY; conferir destaque e aviso, tocar o botão Pets original e verificar grade, equipar/desequipar, abas e fechar.
   Abrir o selo Rebirth e conferir a confirmação original. Abrir SETTINGS e
   alterar música/sons. Abrir a diária e conferir seu fluxo original.
4. Usar perfil novo para conferir faixa e destaque do tutorial: faixa, topo e
   coluna não podem se cruzar. O destaque de equipar deve cercar o novo PETS.
5. Emular 667x375 e 750x381, além de retrato, girando durante Play. Conferir
   chat, analógico, pulo, botão diário e rodapé; medir AbsoluteSize dos botões
   (mínimo 44 px). Conferir os mesmos estados com o tutorial ativo/inativo.
6. Conferir Output sem erros. O líder roda lune run check e formatação.

Não houve teste no Studio nem execução de lune/stylua pelo worker.
Loja, auto-click, ovos triplos e imagens finais continuam fora desta tarefa.
