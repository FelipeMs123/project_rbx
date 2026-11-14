# GDD: Candy Smash Simulator

Documento de game design. Números ficam em `src/shared/Config/`; aqui ficam as regras e o porquê.

## Loop principal (MVP)

1. Bater em Lucky Blocks de doce (clique, toque ou botão no celular).
2. O bloco quebra e solta **moedas** (e às vezes **gemas**).
3. Comprar **ovos** com moedas, que chocam **pets**.
4. Equipar até 3 pets: cada um aumenta o dano.
5. Liberar **áreas** novas, com blocos mais fortes e ovos melhores.
6. **Rebirth**: zerar moedas e áreas em troca de bônus permanente de moedas e gemas.

Público principal no celular: botões grandes, toque direto no bloco, nada que dependa de teclado.

## Fórmulas (módulo puro `src/shared/Logic/Formulas.luau`, tarefa A1)

**Dano por clique**
```
dano = BaseDamage + soma(Multiplier dos pets equipados)
```
Ex.: sem pets = 1; com BearGummy (2) + ChocolateDragon (10) = 13.
É o "Dano Base (1) + Multiplicador dos Pets" do prompt, lido como soma.

**Divisão da recompensa (vários jogadores no mesmo bloco)**
Cada jogador recebe na proporção do dano que causou:
```
moedas_jogador = floor(Coins_do_bloco * dano_do_jogador / MaxHP)
```
As gemas do bloco (poucas, inteiras) vão todas para quem causou mais dano. Empate: quem deu o último golpe.
O dano que passa do HP restante não conta (o último golpe conta só até zerar).
Isso impede "roubar" o bloco que outro jogador quase quebrou.

**Bônus de rebirth (aplicado em `EconomyService.AddCoins`)**
```
moedas_creditadas = floor(moedas * (1 + Rebirths * RebirthCoinBonus))
```

**Custo do rebirth**
```
custo = floor(RebirthBaseCost * RebirthCostGrowth ^ Rebirths)
```
Ao fazer rebirth: `Coins = StartingCoins`, `UnlockedAreas = {StartingArea}`,
`Rebirths += 1`, `Gems += RebirthGemReward`. Pets e gemas ficam.

## Blocos

- Nascem nos `BlockSpawns` de cada área, com tipo sorteado da lista `Areas.<id>.Blocks`
  (ou fixo pelo atributo `BlockType` do spawn).
- HP fica no servidor e é replicado por atributo `HP` para a barra de vida.
- Ao quebrar: some, solta recompensa, e outro nasce no mesmo spawn depois de `RespawnSeconds`.

## Pets e ovos

- Raridades: Common, Uncommon, Rare, Epic, Legendary.
- Ovo: preço fixo; sorteio por peso (`Eggs.<id>.Weights`), com aleatoriedade só no servidor.
- Limites: 3 equipados, 50 no inventário. Ovo com inventário cheio é recusado **antes** de cobrar.
- Pets seguem o dono (todos os jogadores veem), animação feita no cliente.

## Anti-cheat

| Ameaça | Defesa |
|---|---|
| Autoclicker acima de 15 cps | Rate limit por jogador; excesso é descartado (sem kick, por causa de lag) |
| Bater de longe / teleporte | Distância do `HumanoidRootPart` no servidor até o bloco |
| Bater em área bloqueada | `HasArea` antes do dano |
| Cliente inventar recompensa | Cliente só manda `blockId`; o servidor calcula tudo |
| Equipar pet de outro / inexistente | UUID tem que estar no inventário do próprio jogador |
| Duplicar pet entre servidores | Session lock do ProfileStore |
| Spam de remote para derrubar o servidor | Rate limit em todo remote + `pcall` no handler |

## Fora do MVP (fase 2+)

Game Passes e Developer Products (Robux: usar `ProcessReceipt` idempotente; ovo pago em Robux
exige mostrar as chances), troca de pets, fusão de pets (dourado), ranking global
(OrderedDataStore), recompensa diária, auto-clicker pass, mais áreas, sons e música.
