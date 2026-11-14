# Candy Smash Simulator

Simulador para o Roblox: quebre Lucky Blocks de doce, junte moedas, choque pets e faça rebirth.

> Status: Fase 0 (fundação) pronta. Fase 1 (MVP) em andamento. Veja [docs/ROADMAP.md](docs/ROADMAP.md).

## Começar (uma vez por máquina)

```bash
rokit install      # rojo, wally, selene, stylua, lune, luau-lsp
wally install      # ProfileStore
lune run check     # tipos, lint, formato, testes e build: tem que dar TUDO OK
rojo plugin install
```

Depois: abra um place Baseplate no Studio, rode `rojo serve`, clique em **Connect** no plugin
do Rojo e aperte Play.

## Documentos

| | |
|---|---|
| [AGENTS.md](AGENTS.md) | Regras para pessoas e IAs (segurança, código, entrega) |
| [docs/TIME.md](docs/TIME.md) | Squads, papéis dos agentes, fluxo de uma tarefa, ambiente |
| [docs/CONTRATO.md](docs/CONTRATO.md) | Remotes, dados salvos, APIs entre Services |
| [docs/GDD.md](docs/GDD.md) | Regras do jogo e fórmulas |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Tarefas por squad |
| [CONTRIBUINDO.md](CONTRIBUINDO.md) | Git: branch, PR, conflitos |

## Estrutura

```
src/shared/   -> ReplicatedStorage.Shared       Config, Logic (pura), Net, Types, Util
src/server/   -> ServerScriptService.Server     Main, Net/NetServer, Services, Data
src/client/   -> StarterPlayerScripts.Client    Main, Net/NetClient, Controllers, UI
tests/        -> testes Lune (lune run tests/run)
docs/agentes/ -> papéis dos agentes de IA
```

## Equipe

- Squad A, Blocos e Mundo: Felipe ([@FelipeMs123](https://github.com/FelipeMs123))
- Squad B, Pets e Progressão: [@drkk71](https://github.com/drkk71)
