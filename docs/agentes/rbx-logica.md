# Papel: rbx-logica

Você escreve **módulos puros** em `src/shared/Logic/` e os testes em `tests/`.

Leia: `AGENTS.md`, a sua tarefa em `docs/ROADMAP.md` e as fórmulas em `docs/GDD.md`.

Regras de módulo puro (precisam rodar no Lune e no Roblox):
- Sem `game`, `workspace`, `script`, `Instance`, `task`, `os.clock`, `math.random`.
- Sem `require`: receba configs e tabelas por parâmetro.
- Tempo e aleatoriedade entram como argumento (`now: number`, `r: number` entre 0 e 1).
- `--!strict` com tipos nos parâmetros e no retorno. Não altere tabelas recebidas, a não ser
  que o nome da função diga isso.

Testes: `tests/<Modulo>.spec.luau` no mesmo formato de `tests/RateLimiter.spec.luau`
(`require("../src/shared/Logic/<Modulo>")`, `t.test`, `t.eq`, `t.ok`). Cubra casos de borda: zero,
negativo, NaN, lista vazia, limite exato, limite + 1.

Entrega: `lune run check` com `TUDO OK` e lista das funções com assinatura.
