# Receitas de Prompts para Agentes

Uma **receita** é um modelo de prompt reutilizável com lacunas em `{{CHAVES}}`. Qualquer líder de squad (Claude Code, Codex, Overclock) copia o modelo, preenche as lacunas com o contexto da rodada e envia para um agente executar.

## Receitas e Modelos Sugeridos

| Receita | Papel | Nível | Modelo sugerido |
|---|---|---|---|
| [tarefa-roadmap.md](tarefa-roadmap.md) | `rbx-logica` / `rbx-server` / `rbx-client` / `rbx-design` | Simples a Médio | `gpt-6.1-terra`, `gemini-3.8-flash-high` ou `gpt-6.1-sol` |
| [correcao-pr.md](correcao-pr.md) | `rbx-server` / `rbx-client` / `rbx-logica` | Médio | `gpt-6.1-sol` |
| [revisao-diff.md](revisao-diff.md) | `rbx-revisor` | Crítico | `gemini-4-hydrogen-high` ou `gpt-6.1-sol` (high) |
| [teste-studio.md](teste-studio.md) | Testador (Studio MCP) | Médio | `gpt-6.1-sol` |
| [escrivao.md](escrivao.md) | `rbx-escrivao` | Trivial | `gemini-3.8-flash-low` |

### Escala de níveis de modelo
- **Trivial**: `gemini-3.8-flash-low` (diário, resumo, formatação sem decisão técnica).
- **Simples**: `gpt-6.1-terra` ou `gemini-3.8-flash-high` (módulos puros em `Logic/`, testes unitários).
- **Médio**: `gpt-6.1-sol` (Services, Controllers, UI, correções diretas e testes via MCP no Studio).
- **Crítico**: `gemini-4-hydrogen-high` ou `gpt-6.1-sol` (high) (revisão de segurança/anti-exploit, contrato e arquitetura).

## Regra de Ouro da Revisão

**Quem escreveu não revisa.** Código gerado no Codex deve ser revisado pelo Gemini ou pelo Claude, e vice-versa. Modelos diferentes cometem erros diferentes e não têm ponto cego para o próprio código.

## Como Chamar pela Linha de Comando

Salve o prompt preenchido em um arquivo temporário (ex.: `prompt.md`) e chame a ferramenta:

### Codex CLI
```bash
codex exec -m <modelo> -s workspace-write -C <repo> "$(cat prompt.md)" < /dev/null
```

Para o Codex usar o MCP do Roblox Studio sem travar pedindo confirmação em cada ferramenta, acrescente:
```bash
codex exec -m <modelo> -s workspace-write -C <repo> -c 'mcp_servers.Roblox_Studio.default_tools_approval_mode="approve"' "$(cat prompt.md)" < /dev/null
```

### Antigravity CLI (`agy`)
```bash
agy -p "$(cat prompt.md)" --model <modelo> --mode accept-edits
```

### Com modelo reserva (recomendado)
```bash
tools/ia/delegar.sh <trivial|simples|medio|critico> prompt.md [--mcp] [--saida relatorio.txt]
```
Escolhe o modelo pelo nível e, se a cota do primário acabar (rate limit, 429, quota), roda a mesma tarefa no reserva (Codex <-> Gemini). Registra cada tentativa em `.alethe/delegar.log`. Testes: `bash tools/ia/teste-delegar.sh`.

## Boas Práticas ao Preencher `{{CHAVES}}`
1. **Limite os arquivos permitidos**: liste exatamente quais arquivos de `src/` e `tests/` o agente pode criar ou editar.
2. **Proíba commit e push**: o agente entrega o código na árvore de trabalho; o líder roda `lune run check` e faz o commit.
3. **Exporte diffs em arquivo**: para revisão sem terminal, salve `git diff` em um arquivo temporário antes de chamar o revisor.
