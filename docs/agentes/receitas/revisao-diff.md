# Receita: Revisão de Diff (PR ou Correção)

- **Papel**: `rbx-revisor`
- **Modelo sugerido**: Crítico (`gemini-4-hydrogen-high` ou `gpt-6.1-sol` high — sempre um modelo **diferente** do que escreveu o código)
- **Quando usar**: Antes de abrir ou aprovar um PR, ou para validar se um commit de correção resolveu os achados anteriores sem criar regressões.

## Modelo de Prompt

```markdown
Papel: rbx-revisor (siga docs/agentes/rbx-revisor.md e AGENTS.md). Você só relata, não corrige código.
NÃO rode comandos de terminal. Use apenas leitura de arquivos e escreva um único arquivo de saída.

Contexto: {{CONTEXTO_DA_REVISAO}}
O diff está exportado em: {{CAMINHO_DO_DIFF}}
Revisão anterior (se houver): {{CAMINHO_REVISAO_ANTERIOR}}
Arquivos completos relacionados: {{LISTA_ARQUIVOS_COMPLETOS}}

{{SE_REVISAO_DE_CORRECAO_LISTAR_ITENS_PARA_CONFERIR}}

Procure na ordem de prioridade:
1. Exploit e segurança: argumentos do cliente sem validação (tipo, tamanho, NaN/infinito/negativo, posse, distância, saldo), cliente decidindo valor, remote sem rate limit, InvokeClient, dado alterado fora do DataService, cobrança após entrega.
2. Contrato e dados: divergência com docs/CONTRATO.md, escrita com perfil não carregado, yield entre checar saldo e gastar, chave de Config renomeada.
3. Bugs e tipagem: erro de tipo --!strict, jogador saindo no meio (Parent == nil), vazamento de conexões, loop sem task.wait, pcall faltando.
4. Mobile e UI: alvos de toque < 44 px reais com UIScale, sobreposição em tela pequena (ex.: 667x375), modal sem Active = true, dependência de teclado.

Escreva o resultado em {{ARQUIVO_SAIDA}}, em português:
- Se houver itens anteriores: para cada item, indique "RESOLVIDO" ou "NÃO RESOLVIDO" com `arquivo:linha` e motivo.
- "Achados" (ou "Achados novos"): `arquivo:linha: [ALTO|MÉDIO|BAIXO] descrição do problema, como reproduzir/explorar e correção sugerida`.
- Veredito final: **APROVAR** ou **PEDIR MUDANÇAS**.
```

## Exemplo real

> Papel: `rbx-revisor` (siga `docs/agentes/rbx-revisor.md` e `AGENTS.md`). Você só relata, não corrige código. NÃO rode comandos de terminal.
> O diff da correção está em `.alethe/review/pr9-fix.diff`. A revisão anterior está em `.alethe/review/gemini-pr8-pr9.md`.
> Confira, um por um, se os 5 achados foram resolvidos de verdade (sobreposição do `PetsToggleButton` com `HudController`, conta do `updateGridLayout` em 667x375, `Active = true` no modal, botões >= 44 px com `UIScale` 0.78 e `ToastBanner` via `pcall`).
> Procure também bug novo introduzido pela correção (conexões duplicadas, vazamento, erro `--!strict`).
> Escreva o resultado em `.alethe/review/gemini-pr9-fix.md`: cada achado com "RESOLVIDO" ou "NÃO RESOLVIDO" (`arquivo:linha`), "Achados novos" (ALTO/MÉDIO/BAIXO) e veredito: APROVAR ou PEDIR MUDANÇAS.
