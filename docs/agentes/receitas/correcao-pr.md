# Receita: Corrigir Achados de Revisão de PR

- **Papel**: `{{PAPEL}}` (`rbx-server`, `rbx-client` ou `rbx-logica`)
- **Modelo sugerido**: Médio (`gpt-6.1-sol`)
- **Quando usar**: Após uma revisão de PR apontar problemas específicos (com severidade e `arquivo:linha`) que precisam ser corrigidos sem tocar no resto do código.

## Modelo de Prompt

```markdown
Papel: {{PAPEL}} (siga docs/agentes/{{PAPEL}}.md e AGENTS.md). Branch atual: {{BRANCH}}.
NÃO faça commit, branch nem push. {{REGRA_LUNE}}
Só edite os arquivos listados abaixo. Luau --!strict, comentários em português, identificadores em inglês, cabeçalho de arquivo mantido.

A revisão pediu mudanças na branch {{BRANCH}}. Corrija os pontos abaixo, um por um:

{{LISTA_ACHADOS_NUMERADOS_COM_SEVERIDADE_E_ARQUIVO_LINHA}}

Arquivos permitidos:
{{ARQUIVOS_PERMITIDOS}}

Regras:
- Resolva cada item exatamente como pedido, mantendo compatibilidade com docs/CONTRATO.md.
- Se um ajuste afetar testes unitários existentes em tests/, atualize os testes correspondentes.
- Não introduza conexões duplicadas, yields infinitos nem quebras de tipo --!strict.

No fim, escreva um resumo curto: o que mudou por arquivo para cada item, como testar no Studio (não diga que testou se não testou; agentes de código não abrem o Studio) e, se descobrir lição nova, relate no formato: "Lição nova: sintoma -> causa -> o que fazer" (o líder acrescentará em docs/LICOES.md).
```

## Exemplo real

> Papel: `rbx-server` (siga `docs/agentes/rbx-server.md` e `AGENTS.md`). Branch atual: `a/fase1`. NÃO faça commit, branch nem push.
> Corrija os 3 pontos:
> 1) ALTO: `AreaService.Start()` está vazio. Acrescente `Areas.lockedAreaAt` e `Areas.lastUnlocked` em `src/shared/Logic/Areas.luau` (com testes em `tests/Areas.spec.luau`) e o loop de 1 s em `src/server/Services/AreaService.luau`.
> 2) MÉDIO: `src/server/Services/BlockService.luau` ~linha 130-134: o alcance soma metade do tamanho do bloco aos 26 studs; use só `(root.Position - primary.Position).Magnitude <= GameConfig.MaxHitDistance + GameConfig.HitDistanceTolerance`.
> No fim, escreva um resumo curto: o que mudou por arquivo, como testar no Studio e eventual lição nova ("Lição nova: sintoma -> causa -> o que fazer").
