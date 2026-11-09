# 🚀 Início de Projeto: project_rbx

> **Data de início:** 09/11/2026
> **Responsável:** Felipe M. ([@FelipeMs123](https://github.com/FelipeMs123))
> **Status:** 🟡 Planejamento: definindo a ideia do jogo

---

## 1. Visão Geral

**O que é:** um jogo (experiência) para a plataforma **Roblox**.

**Ideia / gênero:** _a definir._ Algumas opções para avaliar:

| Gênero     | Ideia central                                   | Dificuldade para começar |
|------------|-------------------------------------------------|--------------------------|
| Obby       | Percurso de obstáculos com checkpoints          | 🟢 Fácil                 |
| Tycoon     | Construir e expandir um negócio que gera dinheiro | 🟡 Média               |
| Simulator  | Coletar, evoluir, fazer "rebirth"               | 🟡 Média                 |
| RPG/Combate | Missões, armas, inimigos, níveis               | 🔴 Difícil               |

**Público-alvo:** jogadores do Roblox (definir a faixa etária quando a ideia estiver fechada).

---

## 2. Objetivos

| # | Objetivo                                         | Como medir o sucesso                         |
|---|--------------------------------------------------|----------------------------------------------|
| 1 | Definir a ideia e o gênero do jogo               | Seção 1 preenchida e aprovada                |
| 2 | Publicar uma primeira versão jogável (MVP)       | Jogo publicado no Roblox, mesmo que privado  |
| 3 | Testar com outras pessoas                        | Pelo menos 5 pessoas jogaram e deram feedback |

---

## 3. Escopo

### ✅ Dentro do escopo (MVP)
- Um mapa jogável
- A mecânica principal do gênero escolhido
- Salvamento do progresso do jogador (DataStore)

### ❌ Fora do escopo (por enquanto)
- Monetização (Game Passes, Developer Products)
- Vários mapas ou mundos
- Sistema de clãs, trocas ou ranking global

---

## 4. Requisitos

### Funcionais
- [ ] O jogador entra e começa a jogar sem precisar de tutorial longo
- [ ] O progresso é salvo ao sair e carregado ao voltar
- [ ] A mecânica principal funciona de ponta a ponta

### Não funcionais
- [ ] Roda bem no celular (a maior parte do público do Roblox joga no mobile)
- [ ] Lógica importante no **servidor**, nunca confiar só no cliente (evita exploits)
- [ ] Código organizado em ModuleScripts

---

## 5. Stack / Ferramentas

| Camada             | Tecnologia                                         |
|--------------------|----------------------------------------------------|
| Plataforma         | Roblox                                             |
| Linguagem          | Luau                                               |
| Editor             | Roblox Studio (+ VS Code, se usar Rojo)            |
| Sincronização      | _a decidir:_ Rojo ou só o Studio (veja o README)   |
| Dados do jogador   | DataStoreService                                   |
| Controle de versão | Git / GitHub ([project_rbx](https://github.com/FelipeMs123/project_rbx)) |

---

## 6. Cronograma e Marcos

| Marco                     | Entrega esperada                         | Data prevista | Status |
|---------------------------|------------------------------------------|---------------|--------|
| Kickoff                   | Este documento                           | 09/11/2026    | ✅     |
| Ideia definida            | Gênero e mecânica principal escolhidos   |               | ⬜     |
| Ferramentas configuradas  | Studio (+ Rojo) e repositório prontos    |               | ⬜     |
| Protótipo                 | Mecânica principal funcionando no Studio |               | ⬜     |
| MVP publicado             | Jogo publicado no Roblox                 |               | ⬜     |
| Testes com jogadores      | Feedback coletado                        |               | ⬜     |

---

## 7. Equipe e Papéis

| Nome      | Papel                          | Contato                                          |
|-----------|--------------------------------|--------------------------------------------------|
| Felipe M. | Responsável / desenvolvedor    | [@FelipeMs123](https://github.com/FelipeMs123)   |

---

## 8. Riscos e Premissas

| Risco / Premissa                              | Impacto | Plano de mitigação                                   |
|-----------------------------------------------|---------|------------------------------------------------------|
| Escopo grande demais para começar             | Alto    | Focar no MVP; cortar o que não for essencial         |
| Exploits (trapaças) pelo cliente              | Médio   | Validar tudo no servidor (RemoteEvents com checagem) |
| Perda de progresso dos jogadores              | Alto    | Usar DataStore com tratamento de erros (`pcall`)     |
| Código só dentro do Studio, sem histórico     | Médio   | Adotar Rojo para versionar o código no GitHub        |

---

## 9. Próximos Passos

1. [ ] Escolher o gênero e escrever a ideia em 2–3 frases (seção 1)
2. [ ] Decidir entre Rojo ou só o Studio (veja o README)
3. [ ] Criar o place no Roblox Studio
4. [ ] Fazer o primeiro protótipo da mecânica principal

---

## 10. Anotações / Decisões

| Data       | Decisão / Nota                                      |
|------------|-----------------------------------------------------|
| 09/11/2026 | Projeto criado; plataforma: Roblox; gênero em aberto |
