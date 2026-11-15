# Receita: Implementar Tarefa do ROADMAP

- **Papel**: `{{PAPEL}}` (`rbx-logica`, `rbx-server`, `rbx-client` ou `rbx-design`)
- **Modelo sugerido**: Simples (`gpt-6.1-terra` / `gemini-3.8-flash-high` para `rbx-logica`) ou Médio (`gpt-6.1-sol` para `rbx-server` / `rbx-client`)
- **Quando usar**: Para delegar uma tarefa fechada de `docs/ROADMAP.md` em uma branch da squad.

## Modelo de Prompt

```markdown
Papel: {{PAPEL}} (siga docs/agentes/{{PAPEL}}.md e AGENTS.md). Branch atual: {{BRANCH}}.
NÃO faça commit, branch nem push. {{REGRA_LUNE}}
Só crie ou edite os arquivos listados abaixo. Luau --!strict, comentários e textos de UI em português do Brasil, identificadores em inglês e cabeçalho de arquivo com caminho no Roblox, dono e descrição.

Tarefa: {{ID_TAREFA}} de docs/ROADMAP.md — {{TITULO_TAREFA}}.
Leia antes de codar: AGENTS.md, docs/CONTRATO.md, docs/GDD.md e a seção {{ID_TAREFA}} em docs/ROADMAP.md.

Arquivos permitidos:
{{ARQUIVOS_PERMITIDOS}}

Critérios de pronto:
{{CRITERIOS_DE_PRONTO}}

Restrições:
- Não altere arquivos de contrato (Remotes.luau, Types.luau, ErrorCodes.luau, Config/Game.luau, Data/Template.luau) sem parar e avisar.
- Valide todos os argumentos vindos do cliente (tipo, tamanho, NaN/infinito/negativo, posse, distância, saldo).
- Dados só mudam via DataService/EconomyService; remotes só via NetServer/NetClient.

No fim, escreva um resumo curto contendo:
1. O que mudou por arquivo e decisões tomadas.
2. Como testar no Studio (roteiro passo a passo de 3 a 8 passos). Não diga que testou no Studio se não testou (agentes de código não abrem o Studio).
3. O que ficou de fora ou depende de outra tarefa.
4. Se descobrir uma lição nova de pegadinha/ambiente, relate no formato: "Lição nova: sintoma -> causa -> o que fazer" (o líder acrescentará em docs/LICOES.md).
```

## Exemplo real

> Papel: `rbx-server` (siga `docs/agentes/rbx-server.md` e `AGENTS.md`). Branch atual: `a/fase1`.
> NÃO faça commit, branch nem push. Só edite `src/shared/Logic/Areas.luau`, `tests/Areas.spec.luau` e `src/server/Services/AreaService.luau`.
> Tarefa: A3 de `docs/ROADMAP.md` — implementar checagem a cada 1 s em `AreaService.Start()` para devolver personagens em área bloqueada ao `SpawnLocation` da última área liberada e enviar `Notify` com `ErrorCodes.AREA_LOCKED`.
> No fim, escreva um resumo curto: o que mudou por arquivo, como testar no Studio e eventual lição nova ("Lição nova: sintoma -> causa -> o que fazer").
