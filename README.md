# Diário do Candy Smash Simulator

Este branch (`diario`) é a ponte entre as duas squads. Só tem texto, sem código.
Ele não passa por PR: o escrivão de cada squad envia direto, então quem lê vê na hora.

| Arquivo | Quem escreve | O que tem |
|---|---|---|
| `squad-a.md` | escrivão da Squad A (Felipe) | painel das tarefas A + registro de cada rodada |
| `squad-b.md` | escrivão da Squad B (drkk71) | painel das tarefas B + registro de cada rodada |
| `recados.md` | as duas squads | pedidos e avisos de uma squad para a outra |

Regra para não dar conflito: cada squad só edita o próprio `squad-X.md`. Em `recados.md`,
só acrescente no fim (nunca apague nem edite recado de outra squad).

## Quando atualizar

No fim de cada rodada de agentes (um grupo de tarefas que terminou), o líder da squad roda
o escrivão (papel `rbx-escrivao`, modelo leve: Gemini Flash ou Haiku). Depois:

```bash
git -C <pasta-do-diario> add -A
git -C <pasta-do-diario> commit -m "Diário Squad X: <rodada>"
git -C <pasta-do-diario> push origin diario
```

Para ter o diário numa pasta separada sem atrapalhar o seu branch de código:
`git fetch origin diario && git worktree add ../diario diario`

## Formato do `squad-X.md`

```markdown
# Diário da Squad X

## Painel
| Tarefa | Status | Feito por (ferramenta e modelo) | Branch / PR | Bloqueio ou próximo passo |
|---|---|---|---|---|
| X1 Nome | ⬜ a fazer / 🟡 em andamento / 🔵 em teste / ✅ pronto | Codex gpt-6.1-terra | `x/...` #N | ... |

## Registro
(entrada mais nova em cima)

### AAAA-MM-DD · <nome da rodada>   (horário só se vier na entrada)
- **O que foi feito:** ...
- **Como:** agentes, modelos, ordem, comandos importantes
- **Decisões:** ... (e por quê)
- **Problemas e soluções:** ...
- **Testes:** `lune run check` (N testes) / Studio (testado ou não)
- **Próximo passo:** ...
```

## Formato do `recados.md`

```markdown
### AAAA-MM-DD · Squad X para Squad Y · <assunto>
<recado curto e direto>
**Precisa de resposta?** sim/não
```
