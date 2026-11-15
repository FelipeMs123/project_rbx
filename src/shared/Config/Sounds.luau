--!strict
-- Sounds.luau (ReplicatedStorage.Shared.Config.Sounds)
-- Dono: Squad A. substituir "" pelos rbxassetid reais.

export type SoundDef = { AssetId: string, Volume: number }
export type SoundsConfig = { SFX: { [string]: SoundDef }, Music: { [string]: SoundDef } }

local Sounds: SoundsConfig = {
	SFX = {
		BlockHit = { AssetId = "", Volume = 0.45 },
		BlockBreakCommon = { AssetId = "", Volume = 0.65 },
		BlockBreakRare = { AssetId = "", Volume = 0.75 },
		BlockBreakEpic = { AssetId = "", Volume = 0.85 },
		CoinsCollect = { AssetId = "", Volume = 0.50 },
		GemsCollect = { AssetId = "", Volume = 0.65 },
		EggHatch = { AssetId = "", Volume = 0.80 },
		LegendaryPet = { AssetId = "", Volume = 0.95 },
		AreaUnlock = { AssetId = "", Volume = 0.85 },
		Error = { AssetId = "", Volume = 0.45 },
	},
	Music = {
		CandyPlaza = { AssetId = "", Volume = 0.25 },
		ChocolateFalls = { AssetId = "", Volume = 0.25 },
		CottonClouds = { AssetId = "", Volume = 0.25 },
	},
}

return table.freeze(Sounds)
