--!strict
-- Blocks.luau (ReplicatedStorage.Shared.Config.Blocks)
-- Dono: Squad A. Tipos de Lucky Block (pinhatas de doce).
local Types = require(script.Parent.Parent.Types)

local Blocks: { [string]: Types.BlockDef } = {
	GummyBlock = { Name = "Bloco de Goma", MaxHP = 12, Coins = 8, Gems = 0, RespawnSeconds = 4 },
	LollipopBlock = { Name = "Bloco Pirulito", MaxHP = 35, Coins = 22, Gems = 0, RespawnSeconds = 6 },
	ChocoBlock = { Name = "Bloco de Chocolate", MaxHP = 150, Coins = 105, Gems = 1, RespawnSeconds = 8 },
	CloudBlock = { Name = "Bloco de Nuvem", MaxHP = 480, Coins = 340, Gems = 3, RespawnSeconds = 12 },
}

return table.freeze(Blocks)
