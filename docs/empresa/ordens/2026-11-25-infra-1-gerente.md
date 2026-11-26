# Ordem ao gerente de Infra/Gate: fechar A13 (HUD) e PR de docs

Origem: CEO sites-97, com ok do chefe sites-9b (`docs/empresa/caixa/ceo.md`).
Leia antes: `docs/empresa/BASE.md`, `AGENTS.md`, `docs/CONTRATO.md`, `docs/LICOES.md`, `.github/CODEOWNERS`.
Você planeja, não roda terminal. Devolva as ordens dos funcionários no formato da BASE (`id`, `executor`, `effort`, `cwd` absoluto, `arquivos_donos`, `brief`, `criterio_de_aceite`), uma por arquivo em `docs/empresa/ordens/2026-11-25-infra-<n>.md`.

## Objetivo

Levar a A13 ao PR aberto e deixar `docs/empresa/` em PR separado só de docs.

## Estado

- Worktree: `D:\Sites\project_rbx-a13`, branch `a/a13-hud`, 1 commit à frente de `origin/main` (`d529836`) mais alterações não commitadas em `src/client/Controllers/HudController.luau`, `src/client/UI/Hud/SideMenu.luau`, `src/client/UI/Hud/TopBar.luau` e arquivo novo `src/client/UI/Hud/MenuCoordinator.luau`.
- Visual já aprovado pelo dono. QA Studio só se o diff mudar depois disso.
- Checkout principal `D:\Sites\project_rbx` está na `main`, parado. Tem `art/`, `assets/pets/` e `docs/empresa/` não rastreados.

## Decisões já tomadas (não rediscutir)

1. A13 segue o fluxo: pré-gate, `rev-cliente`, gate final, PR. Sem `rev-servidor` (não toca remote, dinheiro ou dados).
2. `art/` e `assets/pets/` NÃO entram em nenhum commit (são do PR #24).
3. `docs/empresa/` vai em PR próprio, branch `a/empresa-docs`, só docs, criado a partir de worktree próprio (`D:\Sites\project_rbx-empresa-docs`) para não mexer no checkout principal.
4. Não fazer merge. Chefe decide depois de CI verde + `APROVADO`.
5. Commit com `-c user.name="Felipe" -c user.email="felipemarques1_2@hotmail.com"`. Nada de push na `main`.
6. O recado à Squad B (`.alethe/a13-pendencias-squad-b.md`, incluindo `MenuCoordinator.Register("Rebirth", RebirthUI.SetModalOpen)`) é do Escrivão no `recados.md` do branch `diario`, não do Infra/Gate. Planeje essa unidade também (Escrivão `gemini-3.8-flash-low`, conferir datas e horários, push no `diario`).

## O que planejar, em sequência

1. **Pré-gate** (sem commit): Codex `gpt-6.1-terra` low via `codex exec` no worktree real `D:\Sites\project_rbx-a13`: `lune run check` até `TUDO OK`. Se vermelho, relatório `FALHOU` com o erro; não corrigir sem ordem.
2. **Revisão:** ordem de exportar o diff para `.alethe/review/a13.patch` (relativo à `origin/main`, incluindo o arquivo novo) e rodar `rev-cliente` (agy `gemini-4-hydrogen-medium`, read-only). A A13 foi escrita por agy/Gemini, então a Revisão deve ser de modelo diferente do autor: propor executor (Codex `gpt-6.1-terra` medium, read-only) e justificar. Foco: sobreposição de UI no celular, API pública do HudController (`Toast`, `SetTopReserve`) preservada, nada de regra de jogo no cliente, não editar arquivos da Squad B, `--!strict`.
3. **Gate final A13:** `gemini-4-argon-medium` com `--dangerously-skip-permissions`: commit das alterações pendentes (ou amend não: novo commit), push `a/a13-hud`, `gh pr create` com o template do repo. Só roda com pré-gate `TUDO OK` e revisão `APROVADO`.
4. **PR de docs:** worktree `D:\Sites\project_rbx-empresa-docs` a partir de `origin/main`, copiar `docs/empresa/` (sem tocar em `art/` e `assets/pets/`), commit, push `a/empresa-docs`, `gh pr create`. Mesmo executor do gate final. Pode rodar em paralelo à Revisão, pois arquivos são disjuntos.
5. **Escrivão:** recado no `recados.md` e andamento em `squad-a.md` do branch `diario`.

## Critério de aceite

- Pré-gate `TUDO OK`; revisão `APROVADO`; PR `a/a13-hud` aberto e CI rodando; PR `a/empresa-docs` aberto só com arquivos de `docs/empresa/`; recado no `diario`.
- `git status` do checkout principal sem mudança nova além do que já estava.

## Cota

Codex 5h 3% / semana 22%; sem restrição. `argon` não consultado: checar `usage` antes do gate final.
