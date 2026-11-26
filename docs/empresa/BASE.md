# Empresa de IAs (project_rbx): base comum

Repositório: `D:\Sites\project_rbx` (GitHub `FelipeMs123/project_rbx`). Stack: Rojo 7.7.1 + Rokit, Luau (`--!strict` em `src/`), ProfileStore (Wally), gate `lune run check` (deve imprimir `TUDO OK`), CI no GitHub Actions. Organograma: `docs/empresa/ORGANOGRAMA.md`. Regras técnicas e segurança do projeto: `AGENTS.md`, `docs/CONTRATO.md` e `docs/LICOES.md`.

## Escopo

- Só a **Squad A** (Felipe): Blocos e Mundo, HUD, efeitos, arte 3D e mapa.
- Pets e Progressão são da **Squad B** do amigo (`@drkk71`) e não são tocados.
- Se o amigo sair do projeto, o dono avisa e o escopo vira o jogo inteiro.
- Arquivos de dono em `.github/CODEOWNERS`.
- Fundação e contrato (`docs/CONTRATO.md`, `Remotes.luau`, `Types.luau`, `ErrorCodes.luau`, `Config/Game.luau`, `Data/Template.luau`, API pública de Service) só mudam com acordo das duas squads.
- Recados para a Squad B vão pelo branch `diario` (`recados.md`).

## Hierarquia

Dono (Felipe) ↔ **Assistente** (Haiku 5.5): canal do dono. Leva ao dono o que é crítico, com o contexto completo, e repassa a resposta literal. Não decide nem aprova.
Dono → **Chefe** (Opus 5.5, sessão Claude Code em `D:\Sites\project_rbx`): decide o que não é crítico; conversa curta com o CEO. → **CEO** (Sonnet 5.5 high, sessão própria, cwd `D:\Sites\project_rbx`) → gerentes → funcionários.

- O CEO decide e reporta só resultado e itens da lista de aprovação. Lê relatórios, não diff longo.
- Gerente planeja e escreve ordens em arquivo. Não roda terminal nem abre workers.
- Funcionário faz só o que a ordem diz.

## Comunicação entre terminais

- Nomes: `docs/empresa/SESSOES.md`. Cada sessão nova registra o próprio nome (`ListAgents`). O CEO lê o arquivo antes de procurar o chefe.
- Chefe ↔ CEO: `SendMessage` para o nome em `SESSOES.md`, com o relatório completo gravado na caixa do destino.
- Caixa por arquivo (funciona com qualquer executor): `docs/empresa/caixa/<destino>.md`, entrada no fim com data, remetente, assunto e o que se espera de volta.
- Ordens: `docs/empresa/ordens/<AAAA-MM-DD>-<time>-<n>.md`.
- Relatórios: `docs/empresa/relatorios/<id>.md`.
- Decisões: `docs/empresa/decisoes/<AAAA-MM-DD>-<tema>.md`.
- Estado: `docs/empresa/ESTADO.md`.
- Workers não conversam entre si: falam só por ordens e relatórios.
- Mensagem ao chefe: resultado curto. Item crítico (lista de aprovação) não vai ao chefe para decisão: vai ao assistente, que pergunta ao dono.
- Assistente: só repassa, literal, nos dois sentidos. Não resume, não decide, não marca aprovação. A única aprovação é a resposta do dono no terminal dele, passada pelo assistente.

## Times e modelos

Sempre o modelo mais barato que dá conta. Effort `medium` é o padrão (`low` no trivial). Não mexer em effort por tarefa.

**Regra de escalada:**
1. Antes de subir modelo ou effort, diagnosticar: ordem vaga, arquivos donos faltando, contexto faltando (`AGENTS.md`, `docs/CONTRATO.md`, `docs/LICOES.md`), testes ausentes no brief. Se sim, corrigir a ordem, não o modelo.
2. Subir effort só se o relatório mostrar arquivo pulado, teste não rodado ou revisão não feita.
3. Subir modelo só se o worker errou com contexto completo.
4. Descer modelo quando a tarefa virou rotina (edição mecânica, texto, teste repetido).
5. Opus só para decisão de arquitetura ou ambiguidade real.
6. Brief curto reduz tokens, mas não é limite.
7. `*-high` do agy já embutem o nível: NÃO passar `effort` no plano (erro "--effort is not supported").

| Time | Gerente | Funcionários |
| --- | --- | --- |
| Design/Produto | agy `gemini-4-hydrogen-medium` | Analista de tarefa (spec com critérios de aceite, remotes cliente × servidor, balanceamento em `Config/`) `gemini-4-hydrogen-medium`; Escrivão/Secretaria (diário no branch `diario`, `docs/empresa/HISTORICO.md`, `docs/LICOES.md`) `gemini-3.8-flash-low`, conferir datas e horários |
| Servidor | agy `gemini-4-hydrogen-medium` | Dev crítico (moedas, gemas, remotes, anti-cheat, `DataService`/ProfileStore) Codex `gpt-6.1-sol` medium; lógica pura em `Logic/` com testes Lune Codex `gpt-6.1-terra` medium; mecânico `gemini-3.8-flash-medium` |
| Cliente/UI | agy `gemini-4-hydrogen-medium` | Dev de telas, HUD e input mobile `gemini-4-hydrogen-medium`; mecânico `gemini-3.8-flash-medium`. Lógica que vale dinheiro nunca no cliente |
| Arte e Mapa | agy `gemini-4-hydrogen-medium` | Modelos 3D via MCP do Blender ou `generate_mesh` do Studio: Codex `gpt-6.1-terra` medium (o Codex tem os dois MCPs); mapa por código (spec `docs/mapa/` → `tools/map/*.luau` → `assets/*.model.json`) Codex `gpt-6.1-terra` medium. Pipeline em `art/README.md` |
| Revisão | agy `gemini-4-hydrogen-medium` | `rev-servidor` (exploit, remote sem validação, dinheiro, quebra de contrato; nunca abaixo de medium) e `rev-cliente`, agy `gemini-4-hydrogen-medium`, read-only, diff exportado para `.alethe/review/<id>.patch`. Modelo diferente do autor (código do Codex revisa Gemini e vice-versa) |
| QA Studio | (o gerente de Revisão escreve o roteiro) | Testador Codex `gpt-6.1-terra` low com MCP do Studio liberado: `codex exec -c 'mcp_servers.Roblox_Studio.default_tools_approval_mode="approve"' ... < /dev/null`. Um testador por vez. Segue `docs/agentes/receitas/teste-studio.md`. Entrega relatório com console e screenshots |
| Infra/Gate | agy `gemini-4-hydrogen-medium` | **Pré-gate** (sem commit): Codex `gpt-6.1-terra` low roda `lune run check` no worktree da tarefa (`codex exec -s danger-full-access`, só `lune run check`, sem editar nem git; o sandbox do Codex no Windows não tem perfil de usuário). **Gate final** (commit, push, `gh pr create`, `gh pr merge` só com ok do chefe): agy `gemini-4-argon-medium` com `--dangerously-skip-permissions`, único com git e gh |

### Cota (regra do chefe)

Vale por provedor e por janela (5h e semana; o `argon` conta como janela própria). Consultar `orchestrate.py usage` antes de cada onda.
- **A partir de 80%:** no máximo 1 worker daquele provedor por vez; o modelo desce um nível; unidade limitada vai para o provedor com folga.
- **A partir de 95%:** pausar aquele provedor até renovar. Não trocar de conta nem de provedor pago (decisão do dono).
- **`argon` a partir de 95%:** o gate final para e avisa o dono. Não rodar o bypass em outro modelo sem ok do dono.

O agy lê só dentro do repo (cwd): esta skill tem cópia em `docs/empresa/BASE.md`; ao mudar a skill, atualizar a cópia.

## Pegadinhas técnicas (colar nos briefs relevantes)

- `rojo serve` cai ao trocar de branch: cada tarefa roda em `git worktree` próprio (`D:\Sites\project_rbx-<id>`), mantendo o checkout principal parado.
- `rojo` só roda na pasta raiz com `rokit.toml`.
- Codex em worktree isolado do Alethe não faz commit e o `lune` falha com "home directory not found": o pré-gate roda via `codex exec -s danger-full-access` no worktree real da tarefa.
- `execute_luau` no Studio com `require` de Service cria cópia separada sem dados de jogadores: testar pelo Client disparando `FireServer`/`InvokeServer` e cliques reais.
- Antes de testar no Studio, conferir pelo MCP que `ServerScriptService.Server.Services` bate com o branch servido pelo `rojo serve`.
- `.model.json`: CFrame sempre com tipo explícito e chave `"attributes"` em minúsculo.
- `gh pr merge --delete-branch` apaga o worktree local associado; remover ou cuidar do worktree antes se necessário.
- `agy` headless (`agy -p`) não lê fora do `cwd` e não roda terminal: começar o brief com "NÃO execute comandos de terminal; use só ferramentas de ler, listar e buscar arquivos".

## Fluxo padrão

1. Pedido do chefe → CEO.
2. Design escreve a spec da tarefa do `docs/ROADMAP.md` (critérios de aceite, remotes cliente × servidor, balanceamento em `Config/` e "como testar").
3. Gerente quebra a spec em ordens com `arquivos_donos` disjuntos.
4. Devs executam na ordem: lógica pura (`Logic/` + testes Lune), depois servidor (`Services/`), depois cliente (`Controllers/` e `UI/`).
5. **Pré-gate (sem commit):** Codex `gpt-6.1-terra` low roda `lune run check` no worktree da tarefa até imprimir `TUDO OK`. Vermelho volta ao dev, sem passar pela Revisão.
6. **Revisão:** só código com pré-gate verde. `rev-servidor` (se tocar remote, dinheiro ou dados) e `rev-cliente` (se tocar UI), em paralelo, read-only, com diff exportado para `.alethe/review/<id>.patch`. `REFAZER` de qualquer um volta ao dev e repete pré-gate e revisão.
7. **QA Studio:** quando houver efeito visível ou multiplayer. Roteiro do gerente de Revisão; testador Codex `gpt-6.1-terra` low com MCP do Studio, um por vez, seguindo `docs/agentes/receitas/teste-studio.md`.
8. **Gate final:** branch `a/<tarefa>`, commit, push, PR com o template do repo (`gh pr create`) via agy `gemini-4-argon-medium`.
9. CI verde no GitHub Actions.
10. Chefe decide o merge (squash) se o PR só toca arquivos da Squad A. Se tocar contrato, fundação ou arquivo da Squad B, espera a aprovação do amigo (`@drkk71`) no GitHub.
11. Escrivão atualiza o diário no branch `diario` (`squad-a.md`, `recados.md` se houver recado) e `docs/empresa/HISTORICO.md`.
12. CEO reporta ao chefe: resultado curto.

## Protocolo de ordens e relatórios

- Ordens: `docs/empresa/ordens/<AAAA-MM-DD>-<time>-<n>.md`. Cada unidade traz: `id`, `executor`, `effort`, `cwd` absoluto, `arquivos_donos` (disjuntos entre unidades paralelas), `brief`, `criterio_de_aceite`, e `como_testar_no_studio` quando houver efeito visível.
- Relatórios: `docs/empresa/relatorios/<mesmo-id>.md` com status `FEITO`, `FALHOU` ou `PRECISA_DONO`, mais o que mudou e o que ficou pendente. Curto.
- `PRECISA_DONO` sobe pelo gerente → CEO → chefe → assistente → dono. Nunca decidir sozinho o que está na lista de aprovação.

## Lista de aprovação (crítico: vai ao dono pelo assistente)

- Publicar ou atualizar o place oficial no Roblox.
- Qualquer gasto (Robux, asset pago, créditos).
- Monetização (gamepass, produto, preço).
- Apagar ou migrar dados do DataStore / ProfileStore.
- Mexer em arquivos ou tarefas da Squad B.
- Mudar contrato ou fundação (`docs/CONTRATO.md`, `Remotes.luau`, `Types.luau`, `ErrorCodes.luau`, `Config/Game.luau`, `Data/Template.luau`).
- Estouro de cota (Codex / Antigravity / Claude).
- Decisão de negócio ou de rumo do jogo.

Merge de PR da Squad A com CI verde e revisão aprovada é decisão do chefe. Cota de 80% e pausa de 95% são automáticas, não passam pelo dono.

## Entrega

- Sempre por PR (nunca push direto na `main`).
- Commit sem identidade global: `-c user.name="Felipe" -c user.email="felipemarques1_2@hotmail.com"`.

## Como rodar

- `orchestrate.py` (Alethe) com `cwd` em `D:\Sites\project_rbx` e `cwd` absoluto no plano.
- Consultar `usage` antes de cada onda (`--refresh-agy` se a leitura do agy estiver velha).
- Um item por worker; `isolate: true` para escritores em paralelo.
- MCP do Alethe só para Codex; agy só pelo `orchestrate.py` (exceto gate final com `gemini-4-argon-medium`).
- O agy só lê dentro do repo: esta skill tem cópia em `docs/empresa/BASE.md`; ao mudar a skill, atualizar a cópia.
- agy: `--mode accept-edits`, cwd no repo (+ `--add-dir` do worktree).

## Lições

Ficam em `docs/LICOES.md` (já existe; acrescentar novas lições, nunca reescrever o arquivo). Workers não editam `docs/LICOES.md`: sugerem no relatório final no formato `Lição nova: sintoma -> causa -> o que fazer` para o líder/escrivão acrescentar.
