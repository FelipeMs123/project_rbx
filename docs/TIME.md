# Time: duas squads, cada uma com seus agentes

## Squads

Cada pessoa é líder de uma squad e dona de **sistemas inteiros**: servidor, cliente,
config e testes do sistema. Assim cada um orquestra os próprios agentes sem pisar no outro.

| | Squad A: Blocos e Mundo | Squad B: Pets e Progressão |
|---|---|---|
| Líder | Felipe (@FelipeMs123) | amigo (@drkk71) |
| Lógica pura | Fórmulas de dano e divisão de recompensa | Inventário, sorteio de ovo, custo de rebirth |
| Servidor | `BlockService` (dano, HP, recompensa, respawn, anti-cheat de clique), `AreaService` (liberar áreas) | `PetService` (inventário, equipar), `EggService` (comprar e sortear), `RebirthService` |
| Cliente | Blocos (clique, HP, efeitos), HUD (moedas, gemas, avisos), portões | Pets seguindo, inventário, chocar ovo, tela de rebirth |
| Config | `Blocks.luau`, `Areas.luau` | `Pets.luau`, `Eggs.luau` |
| Studio | Área Praça dos Doces + modelos dos blocos | Área Cascata de Chocolate + modelos dos pets e ovos |
| Tarefas | A1 a A6 | B1 a B6 |
| Branch | `a/<tarefa>` | `b/<tarefa>` |

As duas squads têm o mesmo formato: 1 tarefa de lógica, 2 de servidor, 2 de cliente e 1 no Studio.

**Fundação / contrato** (`docs/CONTRATO.md`): DataService, EconomyService, NetServer, NetClient,
DataController, Types, Remotes, ErrorCodes, Config/Game. Pronta na Fase 0. Mudança só com as
duas squads de acordo.

Quem é dono de cada arquivo está em `.github/CODEOWNERS`: o GitHub pede a aprovação certa sozinho.

**Ponto de contato entre as squads:** só um. A Squad A chama `PetService.GetDamageBonus` para o
dano; até a B2 ficar pronta o stub devolve 0. Dinheiro e áreas liberadas passam pelo
`EconomyService` da fundação, que já funciona. Ninguém espera ninguém para começar.

## Papéis dos agentes

Os papéis valem para qualquer ferramenta. A descrição completa de cada um está em
`docs/agentes/`. No Claude Code eles também existem como subagentes em `.claude/agents/`.

| Papel | Faz | Não faz | Ferramenta sugerida |
|---|---|---|---|
| **Líder** (você + sessão principal) | Escolhe a tarefa, escreve o brief, delega, integra, roda o check, abre o PR | Escrever muito código direto | Claude Code ou Codex |
| `rbx-server` | Services do servidor, validação de remotes | UI, contrato | Codex (modelo forte) |
| `rbx-client` | Controllers, UI, efeitos, input mobile | Lógica que vale dinheiro | Codex ou Claude Sonnet |
| `rbx-logica` | Módulos puros em `Logic/` + testes Lune | Código com `game:` | Codex (modelo barato) |
| `rbx-design` | Balanceamento, conteúdo de Config, textos, GDD | Código de Service | Antigravity (Gemini) |
| `rbx-revisor` | Lê o diff e caça exploit, bug e quebra de contrato | Corrigir (só relata) | Modelo **diferente** do que escreveu o código |
| `rbx-escrivao` | No fim de cada rodada, atualiza o diário da squad no branch `diario` | Código ou decisão técnica | Modelo leve: Gemini Flash ou Haiku |

Regra de ouro da revisão: quem escreveu não revisa. Código feito pelo Codex é revisado
pelo Claude ou pelo Gemini, e vice-versa. Modelos diferentes erram em lugares diferentes.

Sugestão de modelo por papel (ajuste à conta de cada um):

| Papel | Codex | Antigravity | Claude Code |
|---|---|---|---|
| rbx-server | `gpt-6.1-sol` | | sonnet |
| rbx-client | `gpt-6.1-sol` | `gemini-4-argon-medium` | sonnet |
| rbx-logica | `gpt-6.1-terra` | `gemini-3.8-flash-high` | haiku |
| rbx-design | | `gemini-4-hydrogen-high` | sonnet |
| rbx-revisor | `gpt-6.1-sol` (high) | `gemini-4-hydrogen-high` | sonnet |

## Como chamar um papel

**Claude Code** (na pasta do repo): `use o agente rbx-server para a tarefa A3`.
Os subagentes leem o `AGENTS.md` sozinhos.

**Codex / Antigravity**: abra na pasta do repo (eles leem `AGENTS.md` / `GEMINI.md`) e mande:
```
Papel: siga docs/agentes/rbx-server.md.
Tarefa: A3 do docs/ROADMAP.md.
Entregue com `lune run check` passando.
```

## Fluxo de uma tarefa

1. `git checkout main && git pull`, depois `git checkout -b a/a3-blocos`.
2. Marque a tarefa no ROADMAP como "em andamento" (ou atribua a issue a você).
3. Líder escreve o brief: tarefa, arquivos permitidos, critérios de pronto (copie do ROADMAP).
4. Delegue: lógica pura primeiro (`rbx-logica`), depois servidor (`rbx-server`), depois cliente (`rbx-client`).
5. `lune run check` -> `TUDO OK`.
6. **Teste no Studio** (só humano): `rojo serve`, Connect no plugin, Play. Siga o "Como testar" da tarefa.
7. `rbx-revisor` lê o diff (`git diff main...HEAD`). Corrija o que ele achar.
8. Commit, push e PR. O CI roda o check de novo. A outra squad aprova se mexeu em contrato.
9. Merge (squash). A outra squad faz `git pull`.
10. `rbx-escrivao` atualiza o diário no branch `diario` (o que foi feito, como, modelos, próximos passos).

## Diário: a ponte entre as squads

O branch `diario` tem `squad-a.md`, `squad-b.md` e `recados.md`. Não passa por PR: cada
escrivão envia direto, e a outra squad lê na hora pelo GitHub. Antes de começar uma rodada,
leia o diário da outra squad e os recados. Formato e comandos no `README.md` desse branch.

## Ambiente (uma vez por máquina)

1. Instale o [Rokit](https://github.com/rojo-rbx/rokit) e, na pasta do repo, rode `rokit install`
   (instala rojo, wally, selene, stylua, lune e luau-lsp nas versões do `rokit.toml`).
2. `wally install` (baixa o ProfileStore para `ServerPackages/`).
3. `lune run check` (na primeira vez baixa os tipos do Roblox).
4. Studio: instale o plugin do Rojo (`rojo plugin install`).
5. VS Code: extensões **Luau Language Server** (JohnnyMorganz) e **Rojo**.
6. Studio > Game Settings > Security: ligue "Enable Studio Access to API Services" para
   testar salvamento real. Desligado, o ProfileStore usa modo mock e nada é salvo.

## Testar no Studio

1. Abra um place **Baseplate** novo (cada um tem o seu).
2. No terminal: `rojo serve`. No Studio: plugin Rojo > Connect.
3. Play. O Output deve mostrar `[Server] Candy Smash Simulator iniciado` e nenhum erro vermelho.
4. Para testar com 2 jogadores: aba Test > Clients and Servers > 2 Players.

## Mapa e modelos

O código vive no git; o mapa e os modelos 3D vivem no Studio. Para não perder trabalho:
- Cada squad salva o que é dela em arquivo (`assets/<Nome>.rbxmx`: botão direito > Save to File)
  e faz commit. Quando houver arquivo, a fundação liga ele no `default.project.json`.
- Um `.rbxmx` não faz merge: só uma pessoa mexe em cada arquivo por vez. Avise antes.
- Publicar o jogo: um place oficial (no grupo do Roblox de vocês), atualizado por quem fechar a versão.
