# project_rbx

Jogo em desenvolvimento para o **Roblox**. 🎮

> Status: 🟡 Planejamento. Veja o [documento de início de projeto](INICIO_PROJETO.md).

---

## Como trabalhar no código: duas opções

### Opção 1: Só o Roblox Studio (mais simples)
- Tudo é feito dentro do Roblox Studio.
- O Studio salva as versões na nuvem do Roblox.
- **Ponto fraco:** o código não fica no GitHub. Este repositório guardaria só a documentação.

**Ideal para:** quem está começando e quer focar em aprender o Studio.

### Opção 2: Rojo + VS Code (recomendado a médio prazo)
- O código (`.luau`) fica em arquivos neste repositório.
- O [Rojo](https://rojo.space) sincroniza esses arquivos com o Roblox Studio em tempo real.
- Você escreve no VS Code, testa no Studio e faz commit no GitHub.

**Ideal para:** ter histórico do código, voltar versões e trabalhar em equipe.

Para configurar:
1. Instale o [VS Code](https://code.visualstudio.com/).
2. Instale o Rojo (por exemplo, com o [Aftman](https://github.com/LPGhatguy/aftman) ou o [Rokit](https://github.com/rojo-rbx/rokit)).
3. Instale o plugin do Rojo no Roblox Studio.
4. Rode `rojo init` nesta pasta, e depois `rojo serve`.
5. No Studio, clique em **Connect** no plugin do Rojo.

> 💡 Dá para começar só com o Studio e migrar para o Rojo depois.

---

## Estrutura (se usar Rojo)

```
project_rbx/
├── src/
│   ├── server/   → ServerScriptService (lógica do servidor)
│   ├── client/   → StarterPlayerScripts (lógica do jogador)
│   └── shared/   → ReplicatedStorage (módulos compartilhados)
├── default.project.json
├── INICIO_PROJETO.md
└── README.md
```

---

## Autor

Felipe M. ([@FelipeMs123](https://github.com/FelipeMs123))
