# Como contribuir

Guia rápido para trabalharmos juntos sem atrapalhar um ao outro.

## Regras de ouro
1. **Ninguém envia direto para a `main`.** Todo trabalho entra por Pull Request (PR).
2. **Sempre `git pull` antes de começar.**
3. **Uma branch por tarefa**, com nome curto: `sistema-moedas`, `corrige-checkpoint`.
4. **Pegue uma Issue antes de começar**: atribua a você mesmo (Assignees) para o outro saber que você está nela.
5. **Commits pequenos e frequentes.**

## Passo a passo
```bash
git checkout main
git pull
git checkout -b nome-da-tarefa
# ... trabalha e testa ...
git add .
git commit -m "Descreve o que mudou"
git push -u origin nome-da-tarefa
gh pr create        # ou abra o PR pelo site do GitHub
```

Depois, o **outro** revisa e aprova o PR, e quem abriu faz o merge.
Ao terminar, volte para a `main` e atualize:
```bash
git checkout main
git pull
```

## Roblox Studio
- Mapas, modelos e construção: usar **Team Create** (Home → Collaborate).
- Código: se adotarmos o Rojo, fica neste repositório (pasta `src/`). Veja o [README](README.md).

## Conflitos
Se o Git avisar de conflito, abra o arquivo, procure as marcas `<<<<<<<`, `=======`, `>>>>>>>`,
escolha a versão correta, apague as marcas e faça `git add` + `git commit`.
Na dúvida, chame o outro antes de resolver.
