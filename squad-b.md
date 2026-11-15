# Diário da Squad B

> Escrivão da Squad B: siga o formato do README.md deste branch.

## Painel
| Tarefa | Status | Feito por (ferramenta e modelo) | Branch / PR | Bloqueio ou próximo passo |
|---|---|---|---|---|
| B1 Lógica pura | ✅ pronto | Antigravity gemini-4-hydrogen-high / Codex gpt-6.1-sol | `b/b1-logica-pura` #8 | Aprovado pela Squad A; aguardando autorização de merge na `main` |
| B2 PetService | ⬜ a fazer | — | `b/b2-pet-service` | Aguardando merge do PR #8 (B1) |
| B3 EggService + RebirthService | ⬜ a fazer | — | `b/b3-egg-rebirth-service` | Aguardando merge do PR #8 (B1) e B2 |
| B4 Pets e inventário | ✅ pronto | Codex gpt-6-sol (`rbx-client`) + revisão Codex gpt-6-luna | `b/b4-pets-ui` #9 | Aprovado pela Squad A (`4870928`); aguardando autorização de merge na `main` |
| B5 Ovos e rebirth | 🟡 em andamento | Antigravity gemini-4-hydrogen-high + revisão Codex gpt-6.1-sol | `b/b5-ovos-rebirth` (local) | Implementado e revisado localmente; aguardando B3/PR #8 e alinhamento do pedestal `CandyEgg` com B6 |
| B6 Studio: Cascata de Chocolate | ⬜ a fazer | — | `b/b6-cascata-chocolate` | PR #7 aprovado (`5712f86`); aguardando merge do PR #7 na `main` |

## Registro
(entrada mais nova em cima)

### 2026-11-15 · Rodada 3: re-revisão, reteste MCP no Studio e aprovação (`APPROVE`) do PR #7 (`5712f86`)
- **O que foi feito:** Re-revisão completa do commit `5712f86` no PR #7 da Squad A (auditoria de código + bateria de playtest ao vivo no Roblox Studio via MCP), publicação de review `APPROVE` no PR #7 e atualização de `recados.md` e `squad-b.md` após a Squad A também aprovar o PR #9 (`4870928`).
- **Como:** Auditoria de código do commit `5712f86` por Codex (`gpt-6-sol`), playtest no Roblox Studio via MCP por Codex (`gpt-6-luna`), e publicação da review `APPROVE` no GitHub (`gh pr review 7 --approve`) + atualização do diário por Antigravity (`Gemini 4 Argon`).
- **Decisões:** Aprovar (`APPROVE`) o PR #7 após comprovar que os 2 bloqueios anteriores foram resolvidos sem novos achados (`ALTO`/`MÉDIO`/`BAIXO`), anotar para a B6 os limites de `GateCapNorth/South` (`X = 71.25`), `Bounds` com boa altura e `SpawnLocation` opcional em `ChocolateFalls`, e aguardar autorização explícita dos donos (`drkk71` / `FelipeMs123`) antes de realizar qualquer merge dos PRs #7, #8 e #9 na `main`.
- **Problemas e soluções:** Os dois bloqueios da rodada anterior foram sanados em `5712f86`: `AreaService:Start()` + `Logic/Areas` agora monitoram a cada 1 s jogadores em áreas bloqueadas (com suporte a `Bounds` opcional ou fallback AABB ignorando `Gate`) e devolvem o jogador ao spawn com aviso `AREA_LOCKED`; `BlockService` mede a distância `HumanoidRootPart -> centro do bloco <= 26` studs sem somar `GetExtentsSize()/2`; e `StartingCoins = 25` foi alinhado em `Game.luau`, `Template.luau` e `CONTRATO.md`.
- **Testes:** `lune run check` (`TUDO OK`: luau-lsp 0 erros, selene 0 erros/0 warnings, stylua ok, 29 testes passaram / 0 falharam, build ok) / Studio: testado ao vivo via MCP no commit `5712f86` (`Coins = 25` em `leaderstats` e `CandyHud`; `RequestClick` causando dano a `25.00` e `25.80` studs `HP 12->11->10` e rejeitando `26.20`, `26.80` e `28.00` studs `HP 10->10`; guarda territorial com e sem `Bounds` em `ChocolateFalls` devolvendo avatar de `(100,5,0)` ao spawn da `CandyPlaza` em ~`2.3 s` com `AREA_LOCKED`, sem falso positivo em `X=69`; `UnlockArea("ChocolateFalls")` retornando `NOT_ENOUGH_COINS`; quebra do `GummyBlock` somando `+8` moedas `25 -> 33`).
- **Próximo passo:** Aguardar autorização explícita dos donos para merge dos PRs #7, #8 e #9 na `main` e, em seguida, iniciar B2, B3, PR de B5 e B6 (`ChocolateFalls`).

### 2026-11-15 · Rodada 2: correções do PR #9 (B4), revisão e teste MCP no Studio do PR #7 e respostas no diário
- **O que foi feito:** Correção de todos os achados da Squad A no PR #9 (B4) com push do commit `4870928`. Auditoria adversarial de código e teste prático no Roblox Studio via MCP do PR #7 (`1de24d0`) da Squad A, seguidos de publicação de revisão oficial (`REQUEST CHANGES`) no GitHub. Resposta aos recados pendentes em `recados.md` (aprovação da proposta `StartingCoins = 25` e status dos PRs #7, #8 e #9).
- **Como:** Correções da B4 em `wt-pr9-b4-pets-ui` por Codex (`rbx-client`, `gpt-6-sol`) e revisão cruzada por Codex (`gpt-6-luna`). Auditoria de código do PR #7 por Codex (`gpt-6-sol`) em `wt-pr7-a-fase1` e execução de bateria de testes ao vivo no Roblox Studio via MCP por Codex (`gpt-6-luna`). Consolidação do diário e publicação da revisão no GitHub por Antigravity (`Gemini 4 Argon`).
- **Decisões:** Aprovar a mudança de contrato `StartingCoins` de `100` para `25` em `src/shared/Config/Game.luau`. Solicitar mudanças (`REQUEST CHANGES`) no PR #7 por dois pontos objetivos: `AreaService:Start()` vazio no servidor (`src/server/Services/AreaService.luau:49`) e cálculo de distância em `BlockService.luau:130-134` somando metade do maior eixo de `GetExtentsSize()` aos `26` studs contratuais. Alinhar o placeholder de `EggController` com o pedestal `CandyEgg` em `(0, 2.6, -28)` na integração com a B6.
- **Problemas e soluções:** No teste MCP do PR #7 no Studio, `RequestClick` causou dano real em um bloco Gummy (`Core` `4x4`) a `25,00`, `26,50`, `27,03` e `28,00` studs (`HP 9 -> 7`), confirmando que a folga por `GetExtentsSize()` ultrapassa o teto contratual de `26` studs. Além disso, `ChocolateFalls` e seu `Gate` ainda não existem no place atual por pertencerem à B6, e o console exibiu 3 avisos de `rbxassetid://203785492`. No PR #9, reposicionado o botão Pets para não colidir com o HUD, ajustado o grid para celular e bloqueado clique vazando pelo modal.
- **Testes:** `lune run check` (`TUDO OK` no PR #9 `4870928`, na `b/b5-ovos-rebirth` com 143 verificações em memória e no PR #7 `1de24d0` com 24 testes) / Studio: PR #7 testado via MCP no head `1de24d0` (`CandyPlaza` com 10 blocos e 4 templates com `PrimaryPart = Core`, `CandyHud` em `(0.02, 0.5)`, `UnlockArea` validando `AREA_LOCKED`/`NOT_ENOUGH_COINS`, teste de alcance 25–28 studs). Não testado: multiplayer (2 jogadores), emulador mobile e portões com `ChocolateFalls` construída.
- **Próximo passo:** Aguardar merge do PR #8 para abrir PRs de B2/B3/B5, reavaliação do PR #9 pela Squad A e correção dos 2 bloqueios do PR #7 para iniciar B6.

