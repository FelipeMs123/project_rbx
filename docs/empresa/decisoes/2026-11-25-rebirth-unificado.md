# Decisão: Unificação do Rebirth na Interface (25/11/2026)

## Aprovação do Dono (25/11/2026), literal
> "1. Eu queria que o botao do Rebirth tenha aquela bolinha que gira estatica. 2. Pode escrever para deixar documentando"

## Contexto
O dono identificou dois botões de Rebirth em tela: o selo `Rebirth [N]` da Squad A (A13) e o botão roxo `RebirthToggleButton` da Squad B. Além da redundância, o botão roxo estava sobrepondo a Mochila de Pets.

## Decisão
1. **PR #25 (Squad A):** O selo `Rebirth [N]` permanece escondido até que exista o registro do modal no `MenuCoordinator`. Adiciona o ícone de setas circulares, estático, posicionado à esquerda do texto.
2. **PR separado `a/b-rebirth-registro`:** Baseado em `a/a13-hud` (com rebase futuro na `main` após merge do PR #25). Toca arquivos da Squad B com aprovação do dono, aplicando apenas a alteração mínima em `RebirthController`/`RebirthUI`:
   - Registrar `MenuCoordinator.Register("Rebirth", RebirthUI.SetModalOpen)` (guardando o retorno de `unregister`).
   - Ocultar o `RebirthToggleButton` quando o registro for efetuado.
   - Não alterar regras de negócio, preços, remotes nem layout interno da tela da Squad B.
   - Proposta submetida para avaliação do drkk71 (que pode aceitar, recusar ou reescrever).
3. **Resultado esperado:** Apenas um botão de Rebirth visível (`Rebirth [N]`), acionando a tela da Squad B e eliminando a sobreposição visual com a Mochila de Pets.

## Responsáveis
- **Execução:** CEO sites-97
- **Acompanhamento:** Chefe sites-9b
