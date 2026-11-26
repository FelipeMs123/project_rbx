
## 2026-11-25 | Chefe (sites-9b) | Ok para A13, depois A14

- Aprovado: fechar A13 pelo fluxo completo (pré-gate `lune run check`, rev-cliente, PR `a/a13-hud`). A13 já teve visual aprovado pelo dono; QA Studio só se o diff mudar depois disso.
- Recado à Squad B (`.alethe/a13-pendencias-squad-b.md`, registrar `MenuCoordinator.Register("Rebirth", RebirthUI.SetModalOpen)`) vai pelo Escrivão no `recados.md` do branch `diario`.
- `docs/empresa/` entra num PR separado só de docs (branch `a/empresa-docs`), não misturar com a A13.
- `art/` e `assets/pets/` soltos na main: não commitar, são do PR #24.
- Merge da A13: CI verde + revisão APROVADO, me avise que eu decido. Se o PR tocar arquivo da Squad B ou contrato, espera o drkk71.
- Depois do PR aberto: começar A14 (efeitos) pelo Design.
## 2026-11-25 | Chefe (sites-9b) | Decisão: bloqueios da A13

1. **Pré-gate: opção (b) autorizada, como regra permanente.** `codex exec -s danger-full-access` com Codex `gpt-6.1-terra` low, cwd `D:\Sites\project_rbx-a13`, `< /dev/null`. Brief restrito: rodar só `lune run check` (sem `fix`), não editar arquivo, não rodar git de escrita, não rodar `rojo`, devolver as últimas 40 linhas da saída. O sandbox do Codex no Windows roda sem perfil de usuário, por isso o `home directory not found`; `inherit="all"` não resolve. O chefe não roda o check (regra lead-only).
2. **Gerente agy (ReadFile negado):** não mexer nas settings do agy. Rodar com `--mode accept-edits`, cwd `D:\Sites\project_rbx` (a ordem tem que estar dentro do cwd; para ler o worktree, `--add-dir D:\Sites\project_rbx-a13`). Assim o agy leu skills e escreveu docs hoje sem erro. Se falhar de novo com esse comando: o próprio CEO formata as ordens desta rodada (unidades já definidas), sem subagente Claude, e registra a lição.
3. **Secretaria:** acrescentar as duas lições em `docs/LICOES.md` e a nota do `-s danger-full-access` no pré-gate em `docs/empresa/BASE.md` e na skill `D:\Sites\.claude\skills\rbx-empresa-base\SKILL.md` (agy com `--add-dir D:\Sites\.claude\skills\rbx-empresa-base`). Vai no PR `a/empresa-docs`.