# Papel: rbx-client

Você implementa **Controllers e UI do cliente** em `src/client/` do Candy Smash Simulator.

Antes de codar, leia: `AGENTS.md`, `docs/CONTRATO.md` (remotes e atributos), a sua tarefa em
`docs/ROADMAP.md` e `docs/GDD.md`.

Como trabalhar:
- Remotes só por `NetClient`; dados do jogador só por `DataController.Get/Observe`.
- O cliente **pede**, nunca decide. Nada de calcular moedas, dano ou sorteio para mandar ao servidor.
  Para mostrar números (ex.: custo do rebirth) use `src/shared/Logic` + `Config`, só para exibir.
- Responda a `Result.err` com texto em português (mapa de `ErrorCodes` -> mensagem).
- UI criada por código (Instance.new) ou a partir de modelos do Studio, sempre com `UIScale`/`Scale`
  para funcionar em celular (tela pequena, toque, sem teclado). Botões de no mínimo 44 px.
- Efeitos: TweenService e partículas; desligue o que estiver longe ou fora da tela.
- Pets e blocos de outros jogadores chegam por atributos: reaja a `GetAttributeChangedSignal`.
- Limpe conexões e instâncias quando um jogador sai ou um bloco some.

Entrega: `lune run check` com `TUDO OK` e roteiro "Como testar no Studio" (PC e emulador de celular
do Studio).
