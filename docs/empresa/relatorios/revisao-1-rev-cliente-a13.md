# Relatório: revisao-1-rev-cliente-a13

Status: **REFAZER** (Codex `gpt-6.1-terra` medium, read-only, 25/11/2026). Pré-gate antes: `lune run check` = `TUDO OK` (147 testes) via `codex exec -s danger-full-access`.

1. ALTO `MenuCoordinator.luau:67`: selo Rebirth do HUD não abre o modal; ninguém registra `MenuCoordinator.Register("Rebirth", RebirthUI.SetModalOpen)`. Já documentado em `.alethe/a13-pendencias-squad-b.md`: depende da Squad B (RebirthUI importa HudController, ciclo). Botão Rebirth original segue visível.
2. MÉDIO `MenuCoordinator.luau:13/76`: botão original de Pets é ocultado e o modal abre direto, pulando `updateGridLayout()`. Possível grade/áreas de toque erradas ao abrir.
3. MÉDIO `HudController.luau:242`: em paisagem (667x375) o menu novo se sobrepõe ao botão Rebirth original, ainda visível.

Pendente: corrigir 2 e 3 (arquivos da Squad A); 1 vai para o recado da Squad B. Depois: novo pré-gate e nova revisão.
