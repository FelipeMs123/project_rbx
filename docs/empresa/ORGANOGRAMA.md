# Organograma (project_rbx - Squad A)

## Hierarquia

- **Dono (Felipe):** aprova itens críticos (place oficial, gastos, monetização, DataStore, Squad B, contrato/fundação, cota, negócio).
- **Assistente (Haiku 5.5):** canal literal entre Dono e Chefe/CEO. Não decide nem aprova.
- **Chefe (Opus 5.5, `D:\Sites\project_rbx`):** decide o não crítico, inclusive merge de PR da Squad A com CI verde e revisão aprovada.
- **CEO (Sonnet 5.5 high, `D:\Sites\project_rbx`):** coordena os gerentes, mantém `ESTADO.md` e reporta resultados.
- **Gerentes:** planejam e escrevem ordens em `docs/empresa/ordens/`. Não rodam terminal.
- **Funcionários:** executam ordens pontuais e gravam relatórios em `docs/empresa/relatorios/`.

## Times e modelos

| Time | Gerente | Funcionários |
| --- | --- | --- |
| Design/Produto | agy `gemini-4-hydrogen-medium` | Analista de tarefa `gemini-4-hydrogen-medium`; Escrivão/Secretaria `gemini-3.8-flash-low` |
| Servidor | agy `gemini-4-hydrogen-medium` | Dev crítico Codex `gpt-6.1-sol` medium; Lógica pura (`Logic/` + Lune) Codex `gpt-6.1-terra` medium; Mecânico `gemini-3.8-flash-medium` |
| Cliente/UI | agy `gemini-4-hydrogen-medium` | Dev de telas, HUD e input mobile `gemini-4-hydrogen-medium`; Mecânico `gemini-3.8-flash-medium` |
| Arte e Mapa | agy `gemini-4-hydrogen-medium` | Modelos 3D (Blender/Studio MCP) Codex `gpt-6.1-terra` medium; Mapa por código Codex `gpt-6.1-terra` medium |
| Revisão | agy `gemini-4-hydrogen-medium` | `rev-servidor` e `rev-cliente` agy `gemini-4-hydrogen-medium` (read-only) |
| QA Studio | (roteiro do gerente de Revisão) | Testador Codex `gpt-6.1-terra` low (MCP do Studio, um por vez) |
| Infra/Gate | agy `gemini-4-hydrogen-medium` | Pré-gate Codex `gpt-6.1-terra` low; Gate final agy `gemini-4-argon-medium` (`--dangerously-skip-permissions`) |
