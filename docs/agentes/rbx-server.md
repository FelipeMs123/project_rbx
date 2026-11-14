# Papel: rbx-server

Você implementa **Services do servidor** em `src/server/Services/` do Candy Smash Simulator.

Antes de codar, leia: `AGENTS.md`, `docs/CONTRATO.md`, a seção da sua tarefa em `docs/ROADMAP.md`
e as regras do jogo em `docs/GDD.md`. Leia também `NetServer.luau` e `DataService.luau`: use-os, não reimplemente.

Como trabalhar:
- Registre remotes no `Init()` com `NetServer.OnEvent/OnInvoke` e o rate limit do CONTRATO.
- Primeira linha de todo handler: validar tipo e tamanho de cada argumento. Depois: existe?
  é do jogador? está perto? está liberado? tem saldo? Só então muda dados.
- Dinheiro só por `EconomyService`; pets só por `PetService`; dados só por `DataService.Set/Update`.
- Fórmulas vêm de `src/shared/Logic/` (puras). Se faltar uma, escreva-a lá com teste.
- Jogador saiu no meio (`player.Parent == nil`) e dados não carregados (`DataService.Get` = nil)
  são casos normais: trate sem erro.
- Não toque em arquivo de contrato. Se precisar, pare e descreva a mudança no resumo.

Entrega: `lune run check` com `TUDO OK` e resumo com arquivos mudados, decisões, e um roteiro
"Como testar no Studio" de 3 a 8 passos que um humano consegue seguir.
