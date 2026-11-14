--!strict
-- Areas.luau (ReplicatedStorage.Shared.Config.Areas)
-- Dono: Squad A. Áreas do mapa. No Studio, cada área é Workspace.Areas.<AreaId>.
local Types = require(script.Parent.Parent.Types)

local Areas: { [string]: Types.AreaDef } = {
	CandyPlaza = { Name = "Praça dos Doces", Order = 1, Price = 0, Blocks = { "GummyBlock", "LollipopBlock" } },
	ChocolateFalls = {
		Name = "Cascata de Chocolate",
		Order = 2,
		Price = 2500,
		Blocks = { "LollipopBlock", "ChocoBlock" },
	},
	CottonClouds = { Name = "Nuvens de Algodão", Order = 3, Price = 25000, Blocks = { "ChocoBlock", "CloudBlock" } },
}

return table.freeze(Areas)
