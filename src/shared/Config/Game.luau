--!strict
-- Game.luau (ReplicatedStorage.Shared.Config.Game)
-- Constantes globais do jogo. CONTRATO: mudar exige as duas squads.
-- Valores de balanceamento ficam aqui para ninguém espalhar números mágicos no código.

return table.freeze({
	-- Dados
	DataStoreName = "PlayerData_v1",
	DataVersion = 1,

	-- Progresso inicial
	StartingCoins = 25,
	StartingArea = "CandyPlaza",

	-- Pets
	MaxEquipped = 3,
	MaxInventory = 50,

	-- Combate / anti-cheat
	BaseDamage = 1,
	ClicksPerSecond = 15, -- limite de cliques aceitos por segundo
	ClickBurst = 15, -- quantos cliques seguidos cabem no "balde"
	MaxHitDistance = 20, -- studs entre o HumanoidRootPart e o bloco
	HitDistanceTolerance = 6, -- folga para lag de rede
	EffectsRadius = 150, -- só clientes nesse raio recebem VFX do bloco

	-- Rebirth
	RebirthBaseCost = 10000,
	RebirthCostGrowth = 2.5, -- custo = Base * Growth ^ Rebirths
	RebirthCoinBonus = 0.5, -- +50% de moedas por rebirth
	RebirthGemReward = 5,
})
