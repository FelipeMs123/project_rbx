# Como contribuir

Guia rápido para trabalharmos juntos sem atrapalhar um ao outro.

## Regras de ouro
1. **Ninguém envia direto para a `main`.** Todo trabalho entra por Pull Request (PR).
2. **Sempre `git pull` antes de começar.**
3. **Uma branch por tarefa**, com o prefixo da squad e o código do ROADMAP: `a/a3-blocos`, `b/b2-pets`.
4. **Pegue uma Issue antes de começar**: atribua a você mesmo (Assignees) para o outro saber que você está nela.
5. **Commits pequenos e frequentes.**
6. **`lune run check` antes de todo PR.** O CI roda de novo e bloqueia se falhar.
7. **Quem é dono de cada pasta está em `.github/CODEOWNERS`.** Mexeu em contrato, os dois aprovam.

## Passo a passo
```bash
git checkout main
git pull
git checkout -b a/a3-blocos
# ... trabalha, testa no Studio e roda: lune run check
git add .
git commit -m "Descreve o que mudou"
git push -u origin a/a3-blocos
gh pr create        # ou abra o PR pelo site do GitHub
```

Depois, o **outro** revisa e aprova o PR, e quem abriu faz o merge.
Ao terminar, volte para a `main` e atualize:
```bash
git checkout main
git pull
```

## Roblox Studio
- Código: sempre no repositório (`src/`), sincronizado pelo Rojo. Nunca edite script direto no Studio:
  a próxima sincronização apaga.
- Mapa e modelos: feitos no Studio e salvos em `assets/` (veja "Mapa e modelos" em [docs/TIME.md](docs/TIME.md)).

## Conflitos
Se o Git avisar de conflito, abra o arquivo, procure as marcas `<<<<<<<`, `=======`, `>>>>>>>`,
escolha a versão correta, apague as marcas e faça `git add` + `git commit`.
Na dúvida, chame o outro antes de resolver.
