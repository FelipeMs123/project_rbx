# HUD A13 — integração e validação

Dono: Squad A. `HudController` orquestra `TopBar`, `SideMenu`, `BottomBar` e `Theme`.
`Config/UIIcons` reserva IDs vazios para a futura arte; o HUD usa emojis enquanto isso.

## Integração com os painéis

- O HUD não importa UI/Rebirth, UI/Pets, UI/Eggs nem seus Controllers.
  TopBar, SideMenu e BottomBar importam somente Theme; Theme não tem requires.
- PETS e INVENTORY localizam `PetsToggleButton` com `FindFirstChild(..., true)`,
  mantêm o botão original visível e o destacam por 2,5 s, com aviso para tocá-lo.
  Não existe BindableEvent de abertura nessa UI. A escolha preserva o handler
  original da Squad B, que abre o modal e atualiza a grade; requer um segundo toque.
- O selo Rebirth localiza `RebirthModal` recursivamente, fecha `PetsModal` e altera
  `Visible`. Não chama SetModalOpen nem usa require tardio. A confirmação e as
  ações de fechar/cancelar continuam nos handlers originais da Squad B.
- SETTINGS abre `SoundSettings.ModalOverlay`. A diária usa `DailyUI.SetOpen(true)`.
- O HUD esconde `RebirthToggleButton`, `OpenDaily` e `OpenSettings`, inclusive
  quando surgem depois de sua inicialização. `PetsToggleButton` permanece visível.
- Start espera PlayerGui por no máximo 10 s. Os cliques procuram as instâncias
  novamente, sem espera; se Pets/Rebirth ainda não existe, exibem aviso para tentar novamente.
- `SetTopReserve` reposiciona o topo e os avisos abaixo da faixa do tutorial.
  `CandyToasts` mantém DisplayOrder 100.
- Nas telas baixas, a coluna fica compacta e deslocada para dentro do analógico.
  O topo se desloca somente o necessário para não cruzar essa coluna.

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
