# Sons — A9, parte 1

Seleção em 15/11/2026 para Candy Smash Simulator (8–14 anos), baseada na seção A9 de [balanceamento](balanceamento/2026-11-15-fase2.md). Dono: Squad A / rbx-design.

Foram preenchidas 12 das 13 chaves de `src/shared/Config/Sounds.luau`, mantendo todos os volumes e o contrato. `BlockBreakRare` permanece vazio. As justificativas abaixo são escolhas de design a partir dos nomes e descrições do catálogo, sem avaliação auditiva. São aproximações da direção sonora, não confirmação de todas as camadas da referência.

## Origem e uso

Busca pelo MCP Roblox_Studio `search_asset`, tipo `Audio`, escopo `creator_store`, com termos em inglês. Priorizados assets da conta Roblox; complementados por ProSoundEffects e APMOfficial da biblioteca profissional. Todos os selecionados retornaram como gratuitos no Creator Store; não foram usados uploads de trilhas de outros jogos nem áudios de inventário privado.

A [documentação de áudio da Roblox](https://create.roblox.com/docs/audio/assets) apresenta os áudios do Creator Store como gratuitos para uso nas experiências, incluindo a biblioteca de parceiros profissionais. A [licença APM no Roblox](https://en.help.roblox.com/hc/en-us/articles/360000927163-Using-Licensed-Music-on-Roblox) permite usar essas faixas dentro das experiências Roblox. Não se trata de uma licença para redistribuir os arquivos fora da plataforma. Créditos da biblioteca: Courtesy of Pro Sound Effects; Courtesy of APM Music.

## Seleção

Durações em segundos, medidas no Studio por `Sound.TimeLength` (arredondadas a três casas), e não copiadas da descrição do catálogo. Cada ID abre sua página no Creator Store.

| Chave | ID | Nome | Criador | Duração (s) | Por que serve / aproximação |
|---|---|---|---|---:|---|
| `BlockHit` | [15675059323](https://create.roblox.com/store/asset/15675059323) | Roblox_UI_Bright_Click | Roblox | 0.371 | Ataque breve e brilhante para cliques repetidos; aproxima o estalo da bala, sem afirmar textura crocante. |
| `BlockBreakCommon` | [9113263649](https://create.roblox.com/store/asset/9113263649) | Balloon Pop 3 (SFX) | ProSoundEffects | 0.430 | Estouro de desenho animado para a quebra comum; aproxima a pinhata, sem camada de confete. |
| `BlockBreakRare` | 9113263649 (reserva) | Balloon Pop 3 (SFX) | ProSoundEffects | 0.430 | Reserva: o mesmo da quebra comum. Sem candidato convincente de chocolate com brilho. Os resultados eram madeira, pedras ou efeitos de ossos; não foram usados. |
| `BlockBreakEpic` | [9116405618](https://create.roblox.com/store/asset/9116405618) | Magic Poofs Short Breathy Bursts Punchy 2 (SFX) | ProSoundEffects | 1.119 | Poof mágico curto e encorpado para nuvem; aproxima o estouro fofo, sem sinos adicionais. |
| `CoinsCollect` | [9113849492](https://create.roblox.com/store/asset/9113849492) | Coins Or Keys Jingle 6 (SFX) | ProSoundEffects | 1.245 | Tilintar metálico curto de moedas/chaves, identificando recompensa monetária. |
| `GemsCollect` | [9116394545](https://create.roblox.com/store/asset/9116394545) | Magic Glows Soft Clusters Of Chiming Hits 1 (SFX) | ProSoundEffects | 1.431 | Toques mágicos cintilantes para distinguir gemas das moedas. |
| `EggHatch` | [9113959343](https://create.roblox.com/store/asset/9113959343) | Crack Egg Crunchy 11 (SFX) | ProSoundEffects | 1.018 | Casca de ovo rachando, com textura crocante. Não contém o ta-da adicional pedido na referência. |
| `LegendaryPet` | [1844584698](https://create.roblox.com/store/asset/1844584698) | Winner | APMOfficial | 4.624 | Vinheta de vitória para destacar a recompensa lendária; alternativa à fanfarra de harpa, instrumento não confirmado. |
| `AreaUnlock` | [15675043410](https://create.roblox.com/store/asset/15675043410) | Roblox_UI_Tonal_Stinger | Roblox | 1.472 | Vinheta tonal oficial para pontuar a conquista; não confirma acorde ascendente nem portal. |
| `Error` | [15675062723](https://create.roblox.com/store/asset/15675062723) | Roblox_UI_Whistle_Low | Roblox | 0.331 | Apito grave muito breve como aviso leve; substitui o boing por um sinal oficial curto. |
| `CandyPlaza` | [1846920326](https://create.roblox.com/store/asset/1846920326) | Marionettes | APMOfficial | 30.948 | Candidata de biblioteca encontrada por happy xylophone para o clima lúdico. Instrumentação e 118 BPM não foram confirmados por audição. |
| `ChocolateFalls` | [1837465295](https://create.roblox.com/store/asset/1837465295) | Marimba Paradise (alternate no woodwind) | APMOfficial | 161.400 | Descrição do catálogo confirma marimba e camadas percussivas suaves, clima relaxante e ensolarado. 110 BPM não confirmado. |
| `CottonClouds` | [15675069601](https://create.roblox.com/store/asset/15675069601) | Roblox_UI_Loop_Calm_Music | Roblox | 95.475 | Loop calmo oficial para a área de nuvens; synth, sinos e 105 BPM não confirmados. |

## Validação realizada

Studio conectado: Candy Smash Simulator, place `137544077538328`, universe `10776936914`. Somente datamodel **Edit**, sem Play e sem reprodução de áudio. Para cada ID preenchido: criado um `Sound` temporário em `SoundService`, atribuído `SoundId = "rbxassetid://<id>"`, volume de teste zero e chamado `ContentProvider:PreloadAsync({sound})`. Todos retornaram sem erro, com `IsLoaded = true` e `TimeLength > 0`. Todos os efeitos preenchidos têm menos de 3 s, exceto `LegendaryPet` com 4,624 s (dentro da exceção de aproximadamente 5 s).

As três músicas também foram recarregadas com `Looped = true`: todas carregaram, com mais de 30 s. Isso valida a configuração de repetição; a continuidade musical na emenda não foi avaliada por audição. O Config existente contém apenas AssetId e Volume; a parte 2 deverá aplicar `Looped = true` às músicas.

Cada Sound foi destruído após a leitura (com limpeza de reserva agendada). Verificação final: **0 Sounds temporários restantes**, `RunService:IsRunning() = false`. Nenhum objeto permanente foi criado. A carga no place conectado foi comprovada; não foi executado teste em outro universo.

## Como conferir no Studio, sem Play

1. No Creator Store, abra os IDs da tabela e use a prévia para avaliar timbre, adequação infantil e as aproximações indicadas.
2. Em Edit, crie um Sound temporário em SoundService com o SoundId da tabela, faça PreloadAsync pela Command Bar e confira IsLoaded e TimeLength; nas músicas, atribua Looped = true.
3. Se quiser ouvir, use o preview do Studio, respeitando os volumes do Config; confira especialmente repetição de BlockHit e emendas das músicas.
4. Apague o Sound temporário ao terminar, sem salvar objetos de teste.

## Fora desta parte

SoundController, reprodução ligada a eventos, ajustes de pitch de BlockHit, transições e opções de áudio ficam para a parte 2. Não foram implementadas camadas extras (confete, brilho, sinos, ta-da ou portal) nem confirmados os BPM da referência. Falta encontrar BlockBreakRare. Não foram feitos Play, teste de integração, commit, branch ou push. Lune não foi executado, conforme pedido.

Observação para o líder: os filtros de duração da busca não bastam; houve resultados cuja descrição excedia o limite solicitado, e as durações do catálogo diferiam de TimeLength. A seleção final usa as medições acima.
