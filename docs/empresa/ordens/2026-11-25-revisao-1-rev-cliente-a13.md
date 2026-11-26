# Ordem: rev-cliente da A13 (HUD)

- id: `revisao-1-rev-cliente-a13`
- executor: Codex `gpt-6.1-terra` medium, read-only (autor da A13 é agy/Gemini, revisão por modelo diferente)
- cwd: `D:\Sites\project_rbx-a13`
- arquivos_donos: nenhum (não editar nada)
- brief: ler `AGENTS.md`, `docs/agentes/rbx-revisor.md`, `docs/LICOES.md` e o diff `.alethe/review/a13.patch` (contra `origin/main`, inclui `MenuCoordinator.luau` novo). Foco: sobreposição de UI em celular deitado (667x375, 750x381) e chat do Roblox; API pública do `HudController` (`Toast`, `SetTopReserve`) preservada; nenhuma regra de jogo no cliente; nada editado em arquivos da Squad B (`.github/CODEOWNERS`); `--!strict`; leaks de conexão/instância; `TutorialController` coerente com `SetTopReserve`; botões >= 44 px. Não rodar lune/rojo/git de escrita.
- criterio_de_aceite: veredito `APROVADO` ou `REFAZER`, com achados `arquivo:linha`, severidade e correção sugerida, só problemas reais.
- relatório: resposta final do worker, copiada pelo CEO para `docs/empresa/relatorios/revisao-1-rev-cliente-a13.md`.
