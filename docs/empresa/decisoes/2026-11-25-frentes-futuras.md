# 2026-11-25: frentes futuras (códigos promocionais, troca de pets e afins)

Origem: análise das 4 frentes sugerida pelo Gemini e pedida pelo dono (relatório local em `docs/empresa/relatorios/analise-4-frentes.md`). Decisão do dono, pelo assistente: "Pode ser para depois, deixe tudo isso anotado."

## Troca de pets entre jogadores (Trading): DEPOIS

- Decisão do dono: fica para depois.
- Recomendação do chefe: só retomar com o jogo publicado e com jogadores de verdade.
- Motivos: esforço grande; é o sistema com mais risco de duplicação de pets (troca no meio de uma queda de servidor, dois servidores salvando o mesmo pet, jogador saindo no meio); mexe no inventário, que é da Squad B; exige mudança de contrato (`Remotes`, `Template`).
- Pré-requisitos quando voltar: acordo com a Squad B, troca atômica no servidor (as duas partes confirmam e o servidor move os dois lados de uma vez, com trava por sessão), log de cada troca, e revisão de segurança dedicada.

## Códigos promocionais: aguardando o dono

- Opinião do chefe enviada ao dono em 25/11: vale a pena, esforço pequeno, mas o ganho vem com jogadores. Melhor momento: perto da publicação ou de uma atualização grande.
- Regras se for feito: código só no servidor (config), sem diferenciar maiúscula; um uso por jogador, gravado no perfil (campo novo no `Template`, que é contrato e precisa do acordo da Squad B); prêmio só em moeda do jogo ou boost temporário, nunca algo que se compra com Robux; data de validade; limite de tentativas por minuto.

## Itens da análise que são da Squad B (sugestão enviada ao drkk71 pelo diário)

- B8 Monetização: `ProcessReceipt` grava o recibo no perfil e espera o `SaveAndWait` antes de devolver `PurchaseGranted`. IDs ainda 0. Preços e produtos são decisão do dono.
- B9 Ranking global: `LeaderboardService` com `OrderedDataStore`, cache e respeito aos limites do DataStore.
- Refatoração de `PetInventoryUI.luau` (1671 linhas): extrair `PetInventoryHelpers` com testes.
