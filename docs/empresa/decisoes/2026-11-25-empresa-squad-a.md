# Decisão: estrutura da empresa de IAs (Squad A)

Data: 2026-11-25

## Decisões registradas

1. **Entrega sempre por PR:** nenhum push direto na `main`. Branch `a/<tarefa>` em worktree próprio (`D:\Sites\project_rbx-<id>`). Merge (squash) decidido pelo chefe se o PR só toca arquivos da Squad A e está com CI verde e revisão aprovada; se tocar contrato, fundação ou arquivo da Squad B, aguarda aprovação do `@drkk71` no GitHub.
2. **Escopo restrito à Squad A:** Blocos e Mundo, HUD, efeitos, arte 3D e mapa. Arquivos e tarefas da Squad B não são tocados. Recados para a Squad B vão pelo branch `diario` (`recados.md`).
3. **QA Studio com Codex `gpt-6.1-terra` low:** um testador por vez, com MCP do Roblox Studio liberado via `codex exec -c 'mcp_servers.Roblox_Studio.default_tools_approval_mode="approve"' ... < /dev/null`, seguindo `docs/agentes/receitas/teste-studio.md` e roteiro do gerente de Revisão.
