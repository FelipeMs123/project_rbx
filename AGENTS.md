# AGENTS.md: regras para qualquer IA neste repositório

Vale para Claude Code, Codex, Antigravity e qualquer outro agente. Pessoas também seguem.
Se uma instrução de tarefa conflitar com este arquivo, este arquivo vence. Pare e pergunte.

## O projeto

**Candy Smash Simulator**: simulador do Roblox. O jogador quebra Lucky Blocks de doce,
ganha moedas e gemas, compra ovos, choca pets que aumentam o dano e faz rebirth.

- Linguagem: Luau (`--!strict` em todo arquivo de `src/`).
- Código sincronizado com o Roblox Studio pelo **Rojo** (`default.project.json`).
- Dados salvos com **ProfileStore** (via Wally, em `ServerPackages/`).

Leia antes de mexer:

| Documento | Para quê |
|---|---|
| `docs/CONTRATO.md` | Remotes, dados salvos e APIs entre Services. Não quebre. |
| `docs/GDD.md` | Regras do jogo e fórmulas. |
| `docs/TIME.md` | Squads, quem é dono de quê, papéis dos agentes. |
| `docs/ROADMAP.md` | Tarefas. Trabalhe só na tarefa que você recebeu. |
| `docs/LICOES.md` | Pegadinhas já resolvidas (Rojo, MCP do Studio, agentes). Leia antes. Só o líder edita (ou PR de docs); workers sugerem lições no resumo final. |
| `docs/agentes/receitas/` | Modelos de prompt prontos para delegar tarefas a outros agentes. |

## Onde fica cada coisa

```
src/shared/  -> ReplicatedStorage.Shared   (Config, Logic pura, Net/Remotes, Types, Util)
src/server/  -> ServerScriptService.Server (Main.server, Net/NetServer, Services/, Data/)
src/client/  -> StarterPlayerScripts.Client (Main.client, Net/NetClient, Controllers/, UI/)
tests/       -> testes Lune dos módulos puros (src/shared/Logic)
.lune/check.luau -> portão de qualidade
```

## Regras de segurança (anti-exploit). Não negociáveis.

1. **O servidor decide tudo que vale algo**: dinheiro, dano, HP, pets, sorteios, preços.
   O cliente só pede (`RequestClick(blockId)`), nunca informa resultado (`"ganhei 500"`).
2. **Todo argumento vindo do cliente é hostil.** Valide o tipo (`typeof(x) == "string"`),
   o tamanho (string com até 64 caracteres), se existe (`Config.Pets[id] ~= nil`),
   se pertence ao jogador e se faz sentido agora (distância, área liberada, saldo).
3. **Nenhum Service toca em RemoteEvent direto.** Use `NetServer.OnEvent/OnInvoke/Fire*`,
   que já aplica rate limit e `pcall`. Remote novo entra em `src/shared/Net/Remotes.luau`.
4. **RemoteFunction sempre devolve `Types.Result`** (`{ ok, err?, data? }`) com `err` de
   `Shared.ErrorCodes`. Nunca devolva mensagem de erro interna ao cliente.
5. **Nunca use `RemoteFunction:InvokeClient`** (o cliente pode travar o servidor).
6. **Dados só mudam por `DataService.Set/Update`**, nunca alterando a tabela de `Get()`.
   Gaste antes de entregar (`Spend` antes de `AddPet`) e cheque espaço antes de cobrar.
7. **Números do cliente**: rejeite `NaN` (`x ~= x`), infinito e negativos.

## Regras de código

- Services (servidor) e Controllers (cliente) expõem `Init()` (sem yield, registra handlers)
  e `Start()` (pode fazer yield). São ligados em `Main.server.luau` / `Main.client.luau`.
- Balanceamento (preços, HP, chances) vai em `src/shared/Config/`, nunca no meio do código.
- Lógica testável sem Roblox (fórmulas, sorteio, inventário) vai em `src/shared/Logic/`
  como módulo **puro**: sem `game`, sem `require` (receba config por parâmetro), tempo e
  aleatoriedade injetados. Cada módulo puro tem `tests/<Nome>.spec.luau`.
- Identificadores em inglês; comentários em português do Brasil; textos de UI em inglês (o Roblox traduz automaticamente para o idioma do jogador).
- Cabeçalho de cada arquivo: caminho no Roblox, dono (Squad A/B/fundação) e o que faz.
- Não adicione dependência no `wally.toml` sem pedir.

## Antes de entregar

1. Rode `lune run check` (ou `lune run check fix` para formatar). Tem que terminar em `TUDO OK`.
2. Escreva no resumo final: o que mudou, como testar no Studio (passo a passo) e o que
   ficou de fora. Não diga que testou no Studio se não testou: agentes de código (rbx-server, rbx-client, rbx-logica, rbx-design, rbx-revisor) não abrem o Studio nem dizem que testaram; o teste no Studio é feito pelo humano ou por um agente testador acionado de propósito pelo líder com a receita docs/agentes/receitas/teste-studio.md (MCP Roblox_Studio, um testador por vez, Studio conectado ao rojo serve do branch certo).
3. Não faça commit na `main`, push ou merge sem a pessoa pedir. Branch: `a/<tarefa>` ou `b/<tarefa>`.
4. O andamento de cada squad fica no branch `diario` (`squad-a.md`, `squad-b.md`, `recados.md`).
   Leia antes de começar; o papel `rbx-escrivao` atualiza no fim de cada rodada.

## Limites de escopo

- Mexa só nos arquivos da sua tarefa e da sua squad (`.github/CODEOWNERS`).
- Precisa mudar o contrato (`Remotes.luau`, `Types.luau`, `ErrorCodes.luau`, `Config/Game.luau`,
  `Data/Template.luau`, API pública de Service)? **Pare e descreva a mudança** em vez de fazer.
- Não apague nem renomeie chave de `Config/Pets.luau` ou campo do `Template`: quebra dados salvos.
