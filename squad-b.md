# Diário da Squad B

> Escrivão da Squad B: siga o formato do README.md deste branch.

## Painel
| Tarefa | Status | Feito por (ferramenta e modelo) | Branch / PR | Bloqueio ou próximo passo |
|---|---|---|---|---|
| B1 Lógica pura | ✅ pronto | Antigravity gemini-4-hydrogen-high / Codex gpt-6.1-sol | `b/b1-logica-pura` #8 | Aprovado pela Squad A; aguardando merge na `main` |
| B2 PetService | ⬜ a fazer | — | `b/b2-pet-service` | Aguardando merge do PR #8 (B1) |
| B3 EggService + RebirthService | ⬜ a fazer | — | `b/b3-egg-rebirth-service` | Aguardando merge do PR #8 (B1) e B2 |
| B4 Pets e inventário | 🔵 em teste | Codex gpt-6-sol (`rbx-client`) + revisão Codex gpt-6-luna | `b/b4-pets-ui` #9 | Correções da revisão aplicadas (`4870928`); aguardando nova revisão da Squad A |
| B5 Ovos e rebirth | 🟡 em andamento | Antigravity gemini-4-hydrogen-high + revisão Codex gpt-6.1-sol | `b/b5-ovos-rebirth` (local) | Implementado e revisado localmente; aguardando B3/PR #8 e alinhamento do pedestal `CandyEgg` com B6 |
| B6 Studio: Cascata de Chocolate | ⬜ a fazer | — | `b/b6-cascata-chocolate` | Aguardando aprovação/merge do PR #7 (mapa base A6) |

## Registro
(entrada mais nova em cima)

### 2026-11-15 · Rodada 2: correções do PR #9 (B4), revisão e teste MCP no Studio do PR #7 e respostas no diário
- **O que foi feito:** Correção de todos os achados da Squad A no PR #9 (B4) com push do commit `4870928`. Auditoria adversarial de código e teste prático no Roblox Studio via MCP do PR #7 (`1de24d0`) da Squad A, seguidos de publicação de revisão oficial (`REQUEST CHANGES`) no GitHub. Resposta aos recados pendentes em `recados.md` (aprovação da proposta `StartingCoins = 25` e status dos PRs #7, #8 e #9).
- **Como:** Correções da B4 em `wt-pr9-b4-pets-ui` por Codex (`rbx-client`, `gpt-6-sol`) e revisão cruzada por Codex (`gpt-6-luna`). Auditoria de código do PR #7 por Codex (`gpt-6-sol`) em `wt-pr7-a-fase1` e execução de bateria de testes ao vivo no Roblox Studio via MCP por Codex (`gpt-6-luna`). Consolidação do diário e publicação da revisão no GitHub por Antigravity (`Gemini 4 Argon`).
- **Decisões:** Aprovar a mudança de contrato `StartingCoins` de `100` para `25` em `src/shared/Config/Game.luau`. Solicitar mudanças (`REQUEST CHANGES`) no PR #7 por dois pontos objetivos: `AreaService:Start()` vazio no servidor (`src/server/Services/AreaService.luau:49`) e cálculo de distância em `BlockService.luau:130-134` somando metade do maior eixo de `GetExtentsSize()` aos `26` studs contratuais. Alinhar o placeholder de `EggController` com o pedestal `CandyEgg` em `(0, 2.6, -28)` na integração com a B6.
- **Problemas e soluções:** No teste MCP do PR #7 no Studio, `RequestClick` causou dano real em um bloco Gummy (`Core` `4x4`) a `25,00`, `26,50`, `27,03` e `28,00` studs (`HP 9 -> 7`), confirmando que a folga por `GetExtentsSize()` ultrapassa o teto contratual de `26` studs. Além disso, `ChocolateFalls` e seu `Gate` ainda não existem no place atual por pertencerem à B6, e o console exibiu 3 avisos de `rbxassetid://203785492`. No PR #9, reposicionado o botão Pets para não colidir com o HUD, ajustado o grid para celular e bloqueado clique vazando pelo modal.
- **Testes:** `lune run check` (`TUDO OK` no PR #9 `4870928`, na `b/b5-ovos-rebirth` com 143 verificações em memória e no PR #7 `1de24d0` com 24 testes) / Studio: PR #7 testado via MCP no head `1de24d0` (`CandyPlaza` com 10 blocos e 4 templates com `PrimaryPart = Core`, `CandyHud` em `(0.02, 0.5)`, `UnlockArea` validando `AREA_LOCKED`/`NOT_ENOUGH_COINS`, teste de alcance 25–28 studs). Não testado: multiplayer (2 jogadores), emulador mobile e portões com `ChocolateFalls` construída.
- **Próximo passo:** Aguardar merge do PR #8 para abrir PRs de B2/B3/B5, reavaliação do PR #9 pela Squad A e correção dos 2 bloqueios do PR #7 para iniciar B6.

