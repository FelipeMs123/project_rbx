--!strict
-- Eggs.luau (ReplicatedStorage.Shared.Config.Eggs)
-- Dono: Squad B. Ovos compráveis. Weights = chance relativa de cada PetId.
-- MVP: só ovos com moeda do jogo. Ovo pago em Robux exige mostrar as chances (regra do Roblox).
local Types = require(script.Parent.Parent.Types)

local Eggs: { [string]: Types.EggDef } = {
	CandyEgg = {
		Name = "Ovo de Doce",
		Price = 100,
		Currency = "Coins",
		Area = "CandyPlaza",
		Weights = { CottonCat = 60, BearGummy = 30, LollipopBunny = 10 },
	},
	ChocolateEgg = {
		Name = "Ovo de Chocolate",
		Price = 2500,
		Currency = "Coins",
		Area = "ChocolateFalls",
		Weights = { BearGummy = 50, LollipopBunny = 35, JellyUnicorn = 14, ChocolateDragon = 1 },
	},
}

return table.freeze(Eggs)
