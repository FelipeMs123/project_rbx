# Decisão: Mockup do HUD e Transição de Idioma para Inglês

**Data:** 25/11/2026

## Decisão do dono (25/11/2026)
"A. Vamos utilizar a do Gemini, gostei dele. B. Deixe em inglês."

## O que muda
1. O HUD da A13 segue o mockup do Gemini (menu em grade de 2 colunas à esquerda, bolinha vermelha no DAILY, moedas e gemas no topo à direita, Rebirth [N], AUTO-CLICK e x3 EGGS com ícone);
2. O selo Rebirth [N] da A13 só aparece depois que a Squad B registrar `MenuCoordinator.Register("Rebirth", ...)`, o botão roxo da Squad B segue sozinho até lá;
3. Textos de UI da Squad A passam para inglês: HUD (PR #25), depois diária, tutorial, avisos, nomes de blocos e de áreas (PR `a/textos-en`, depois do merge do #25); textos da Squad B: recado ao drkk71.

## Regra de idioma
O `AGENTS.md` ainda diz "textos de UI em português"; é regra comum às duas squads, então a mudança vai em PR próprio (`a/agents-idioma`) para o drkk71 aprovar; até lá o inglês vale para os arquivos da Squad A por decisão do dono.

## Quem
CEO sites-97 executa; chefe sites-9b acompanha.
