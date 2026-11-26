# Estado atual (project_rbx - Squad A)

Atualizado em: 2026-11-25 (CEO sites-97).

## Em andamento

- **A13 (HUD novo):** PR #25 aberto (`a/a13-hud`, commit `b9b577c`). Pré-gate `TUDO OK` (147 testes), rev-cliente APROVADO na 3ª rodada, CI do GitHub rodando. Falta: CI verde, merge pelo chefe, recado à Squad B no `diario`, teste Studio em 667x375 e 750x381 (só revisão estática até aqui).
- **PR de docs:** `docs/empresa/` em branch `a/empresa-docs` (worktree `D:\Sites\project_rbx-empresa-docs`), com as lições novas em `docs/LICOES.md` e a nota do pré-gate em `docs/empresa/BASE.md`.

## PRs abertos aguardando Squad B

- **PR #23:** plano Fase 3.
- **PR #24:** Urso de Goma (`art/` e `assets/pets/` soltos na `main` são do PR #24: não commitar).
- **PR #25:** A13 HUD (Squad A; `TutorialController.luau` cai no `*` do CODEOWNERS).

## Próximas tarefas da Squad A

- **A14:** efeitos (próxima, começa pelo Design depois do PR da A13)
- **A11:** blocos 3D
- **A12:** decoração 3D
- **A15:** áreas 4-6

## Decisões do chefe (25/11)

- Pré-gate roda com `codex exec -s danger-full-access`, só `lune run check`, sem editar nem git (o sandbox do Codex no Windows não tem perfil de usuário: `home directory not found`).
- Gerente agy: `--mode accept-edits`, cwd no repo (+ `--add-dir` do worktree). Não mexer nas settings do agy. Falhou de novo: o CEO formata as ordens.
- `docs/empresa/` em PR separado só de docs.

## Pendências

- Recado Squad B (`MenuCoordinator.Register("Rebirth", RebirthUI.SetModalOpen)`) no `recados.md` do `diario`.
- Lição: revisor Codex read-only precisa de permissão explícita de leitura no brief ("pode usar cat/sed/rg"), senão responde que não consegue ler o patch.
