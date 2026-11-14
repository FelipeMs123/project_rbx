--!strict
-- Blocks.luau (ReplicatedStorage.Shared.Config.Blocks)
-- Dono: Squad A. Tipos de Lucky Block (pinhatas de doce).
local Types = require(script.Parent.Parent.Types)

local Blocks: { [string]: Types.BlockDef } = {
	GummyBlock = { Name = "Bloco de Goma", MaxHP = 10, Coins = 5, Gems = 0, RespawnSeconds = 5 },
	LollipopBlock = { Name = "Bloco Pirulito", MaxHP = 40, Coins = 25, Gems = 0, RespawnSeconds = 8 },
	ChocoBlock = { Name = "Bloco de Chocolate", MaxHP = 250, Coins = 180, Gems = 1, RespawnSeconds = 12 },
	CloudBlock = { Name = "Bloco de Nuvem", MaxHP = 1500, Coins = 1200, Gems = 3, RespawnSeconds = 20 },
}

return table.freeze(Blocks)
