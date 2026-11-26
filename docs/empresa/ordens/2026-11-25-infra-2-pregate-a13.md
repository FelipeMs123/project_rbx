# Ordem: pré-gate A13

- id: `infra-2-pregate-a13`
- executor: Codex `gpt-6.1-terra`, effort low
- cwd: `D:\Sites\project_rbx-a13`
- arquivos_donos: nenhum (não editar nada, não fazer commit/branch/push)
- brief: rode `lune run check` no worktree e reporte a saída. Se o sandbox falhar com "home directory not found", reporte isso e pare. Não corrija código.
- criterio_de_aceite: saída termina em `TUDO OK`; senão, status `FALHOU` com as linhas de erro exatas.
- relatório: `docs/empresa/relatorios/infra-2-pregate-a13.md` (no checkout `D:\Sites\project_rbx`), status `FEITO`/`FALHOU`, curto.

Origem: CEO sites-97. Gerente de Infra falhou 2x no agy (ReadFile negado); esta unidade é fixa e foi despachada direto.
