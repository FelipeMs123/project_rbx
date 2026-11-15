--!strict
-- Fusion.luau (ReplicatedStorage.Shared.Config.Fusion)
-- Dono: Squad B. fusão 5->1 Dourado.

export type FusionConfig = {
	RequiredCount: number,
	GoldenMultiplier: number,
	AllowRefuseGolden: boolean,
	GemCostByRarity: { [string]: number },
}

local Fusion: FusionConfig = {
	RequiredCount = 5,
	GoldenMultiplier = 2.0,
	AllowRefuseGolden = false,
	GemCostByRarity = { Common = 5, Uncommon = 10, Rare = 20, Epic = 35, Legendary = 50 },
}

return table.freeze(Fusion)
