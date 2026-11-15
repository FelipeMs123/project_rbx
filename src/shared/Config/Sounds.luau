--!strict
-- Sounds.luau (ReplicatedStorage.Shared.Config.Sounds)
-- Dono: Squad A. Áudios públicos validados em Edit; seleção e limites em docs/sons.md.

export type SoundDef = { AssetId: string, Volume: number }
export type SoundsConfig = { SFX: { [string]: SoundDef }, Music: { [string]: SoundDef } }

local Sounds: SoundsConfig = {
	SFX = {
		BlockHit = { AssetId = "rbxassetid://15675059323", Volume = 0.45 },
		BlockBreakCommon = { AssetId = "rbxassetid://9113263649", Volume = 0.65 },
		-- Reserva: mesmo som da quebra comum até achar um de chocolate (docs/sons.md).
		BlockBreakRare = { AssetId = "rbxassetid://9113263649", Volume = 0.75 },
		BlockBreakEpic = { AssetId = "rbxassetid://9116405618", Volume = 0.85 },
		CoinsCollect = { AssetId = "rbxassetid://9113849492", Volume = 0.50 },
		GemsCollect = { AssetId = "rbxassetid://9116394545", Volume = 0.65 },
		EggHatch = { AssetId = "rbxassetid://9113959343", Volume = 0.80 },
		LegendaryPet = { AssetId = "rbxassetid://1844584698", Volume = 0.95 },
		AreaUnlock = { AssetId = "rbxassetid://15675043410", Volume = 0.85 },
		Error = { AssetId = "rbxassetid://15675062723", Volume = 0.45 },
	},
	Music = {
		CandyPlaza = { AssetId = "rbxassetid://1846920326", Volume = 0.25 },
		ChocolateFalls = { AssetId = "rbxassetid://1837465295", Volume = 0.25 },
		CottonClouds = { AssetId = "rbxassetid://15675069601", Volume = 0.25 },
	},
}

return table.freeze(Sounds)
