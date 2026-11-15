# Diário da Squad A

## Painel
| Tarefa | Status | Feito por (ferramenta e modelo) | Branch / PR | Bloqueio ou próximo passo |
|---|---|---|---|---|
| A1 Fórmulas | 🔵 em teste | Codex gpt-6.1-sol / Gemini gemini-4-hydrogen-high | `a/fase1` #7 | Aprovação do PR #7 pela Squad B ou merge pelo Felipe |
| A2 BlockService | 🔵 em teste | Codex gpt-6.1-sol / Codex gpt-6.1-terra | `a/fase1` #7 | Aprovação do PR #7 pela Squad B ou merge pelo Felipe |
| A3 AreaService | 🔵 em teste | Codex gpt-6.1-sol / Codex gpt-6.1-terra | `a/fase1` #7 | Aprovação do PR #7 pela Squad B ou merge pelo Felipe |
| A4 Cliente dos blocos | 🔵 em teste | Codex gpt-6.1-sol / Codex gpt-6.1-terra | `a/fase1` #7 | Aprovação do PR #7 pela Squad B ou merge pelo Felipe |
| A5 HUD e portões | 🔵 em teste | Codex gpt-6.1-sol / Codex gpt-6.1-terra | `a/fase1` #7 | Aprovação do PR #7 pela Squad B ou merge pelo Felipe |
| A6 Studio: Praça dos Doces | 🔵 em teste | Gemini 4 Argon + Codex gpt-6.1-sol + Gemini 3.8 Flash | `a/fase1` #7 | Aprovação do PR #7 pela Squad B ou merge pelo Felipe |

## Registro
(entrada mais nova em cima)

### 2026-11-14 · Rodada 4: teste no Studio via MCP e mapa A6
- **O que foi feito:** Teste completo do PR #7 no Studio via MCP (servidor inicia, quebra de bloco e recompensa exatas, anti-cheat de distância, rate limit de 100 cliques para 15 aceitos, argumentos lixo ignorados, UnlockArea em todos os casos, compra da Cascata cobrando 1800 moedas). Ajustes no HUD (painel de moedas movido para lateral esquerda para não ficar sob o chat; barra de HP e preço do portão legíveis com escala e mínimo em pixels de 137x43 px). Implementação da A6 (Praça dos Doces e modelos dos 4 blocos gerados por código, chão subido para Y 0.1, fallback para Core como PrimaryPart e remoção do SpawnLocation do template Baseplate).
- **Como:** Registro e testes no Roblox Studio via MCP pelo líder (Claude Opus). Spec da A6 pelo Gemini 4 Argon, gerador Lune e .model.json pelo Codex gpt-6.1-sol, correções do Rojo e da barra de HP pelo Gemini 3.8 Flash, ajuste do painel de moedas e remoção de SpawnLocation pelo líder Claude Opus.
- **Decisões:** Mover painel de moedas para lateral esquerda para evitar sobreposição com chat do Roblox. Subir chão para Y 0.1 para evitar z-fighting com o Baseplate. Usar a Part Core como reserva de PrimaryPart no BlockService quando PrimaryPart não chegar via sync ao vivo.
- **Problemas e soluções:** Chat do Roblox cobria o painel de moedas; solucionado movendo o painel para a lateral esquerda. Barra de HP sumia (media 66x18 px só com escala); corrigido com escala mais mínimo em pixels (137x43 px). Rojo recusou formato de .model.json; líder descobriu 3 regras (CFrame com tipo explícito, chave attributes minúscula, PrimaryPart via Rojo_Id/Rojo_Target_PrimaryPart), gpt-6.1-terra falhou ao gravar o arquivo e Gemini 3.8 Flash aplicou a correção. PrimaryPart não chega no sync ao vivo; BlockService passou a usar Part Core como reserva. Z-fighting do chão com Baseplate; chão subido para Y 0.1.
- **Testes:** Studio via MCP: tudo passou (mapa com 65 Parts, 10 blocos com modelo de presente nos spawns do mapa, quebra e recompensa ok, jogador nasce no spawn da praça). Não testado: 2 jogadores, celular, salvamento real, portões (dependem da Cascata da Squad B).
- **Próximo passo:** Aprovação do PR #7 pela Squad B ou merge pelo Felipe.

### 2026-11-14 · Rodada 3: correções da revisão
- **O que foi feito:** Correção dos 7 achados da revisão do Gemini no PR #7 (portão aberto não bloqueia clique com CanQuery e raycast só em Workspace.Blocks; prompt do portão na PrimaryPart ou peça mais baixa; balanço move o Model inteiro; avisos do HUD abaixo do painel e cabendo no celular; sem aviso "+0 moedas"; dano formatado com 1 casa fracionária; BillboardGui em escala). Criação do papel rbx-escrivao em docs/agentes, regras do diário em AGENTS.md e TIME.md, e criação do branch diario. Commit 8aef515.
- **Como:** Correções feitas por Codex gpt-6.1-terra chamado direto com codex exec. Revisão do diff e formatação stylua pelo líder Claude Opus. Escrivão rodando em gemini-3.8-flash-low.
- **Decisões:** não informado
- **Problemas e soluções:** Na primeira tentativa o codex exec em segundo plano travou esperando entrada do terminal ("Reading additional input from stdin") sem alterar nada; solucionado rodando com `< /dev/null`. O gpt-6.1-terra não conseguiu rodar o lune ("home directory not found"); o líder rodou, formatou com stylua e validou os testes.
- **Testes:** `lune run check` (24 testes, TUDO OK) / Studio: não testado (falta o Felipe testar o PR #7 no Studio).
- **Próximo passo:** Felipe testar o PR #7 no Studio; A6 (Studio) a fazer.

### 2026-11-14 · Rodada 2: Gemini (design e revisão)
- **O que foi feito:** Balanceamento da curva de progressão e revisão técnica do PR #7.
- **Como:** Gemini gemini-4-hydrogen-high como rbx-design e rbx-revisor; correções sendo feitas com Codex gpt-6.1-terra.
- **Decisões:** Ajuste nos custos e HPs (CottonClouds 6000, ChocolateFalls 1800, CloudBlock 480 HP, ChocoBlock 150 HP, Gummy e Lollipop ajustados) para evitar 1º rebirth antes da 3ª área e reduzir cliques excessivos no mobile. Meta: 2ª área em 6 a 8 min, 1º rebirth em 25 a 32 min. Relatório em `docs/balanceamento/2026-11-14-curva-mvp.md`. Sugestões de StartingCoins 25 e balanceamento de ovos enviadas para `recados.md`.
- **Problemas e soluções:** Revisão apontou 7 achados (4 médios: colisão de portão invisível bloqueando clique, prompt em peça alta, animação de balanço só na PrimaryPart, sobreposição de HUD e avisos no celular; 3 baixos: aviso de "+0 moedas", dano sem formatação e BillboardGui em pixels fixos). Solução: correções iniciadas com Codex gpt-6.1-terra.
- **Testes:** não informado nesta rodada / Studio: não testado.
- **Próximo passo:** Líder revisar as correções do gpt-6.1-terra, rodar checagens e subir para o PR #7; Felipe testar PR #7 no Studio e iniciar A6.

### 2026-11-14 · Rodada 1: tarefas A1 a A5
- **O que foi feito:** Implementação das fórmulas e BlockService (A1+A2), AreaService (A3), cliente dos blocos (A4), HUD de moedas/gemas, avisos e portões das áreas (A5).
- **Como:** 4 workers do Codex (gpt-6.1-sol via Alethe) em paralelo em worktrees isolados, seguidos de revisão e integração pelo líder (Claude Opus).
- **Decisões:** Unir A1 e A2 no mesmo worker. Criar branch `a/fase1` e PR #7 com um commit por tarefa.
- **Problemas e soluções:** Sandbox do Codex impediu criação de branch e commits no worktree (worker A1+A2 parou e precisou ser relançado só para edição de arquivos); líder assumiu criação de branches, checagens e commits. Na revisão, Claude corrigiu erro de tipo e checagem duplicada na A3, e corrigiu bug na A4 onde clique contínuo no PC falhava por conta da barra superior (`GetMouseLocation` menos `GetGuiInset`).
- **Testes:** `lune run check` (24 testes, TUDO OK, CI verde) / Studio: não testado.
- **Próximo passo:** Revisão de design e código (Rodada 2) e testes no Studio.

### 2026-11-14 · Fase 0: fundação
- **O que foi feito:** Reinício da estrutura do repositório do zero com Rojo, Rokit, Wally e ferramentas auxiliares. Criação de DataService, EconomyService, NetServer/NetClient, stubs, configs, documentação completa e CI.
- **Como:** Desenvolvido pelo Claude Opus (sessão principal) com revisão cruzada pelo Codex (gpt-6.1-sol).
- **Decisões:** Rebalanceamento da divisão do projeto em 6 tarefas para cada squad a pedido do Felipe; economia base passou para a fundação. Mesclado via PR #6 na `main` com squash.
- **Problemas e soluções:** Revisão do Codex apontou 3 problemas (cliente sem retry no GetData, require antes de replicação e RemoteFunction sem handler travando o cliente); todos foram corrigidos pelo Claude antes do merge.
- **Testes:** `lune run check` (TUDO OK, CI configurado) / Studio: não informado.
- **Próximo passo:** Iniciar tarefas da Fase 1 da Squad A (A1 a A5).
