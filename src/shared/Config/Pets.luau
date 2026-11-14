--!strict
-- Pets.luau (ReplicatedStorage.Shared.Config.Pets)
-- Dono: Squad B. Definições de pets. A chave é o PetId salvo no inventário:
-- NUNCA renomear uma chave já publicada (quebra o inventário de quem tem o pet).
local Types = require(script.Parent.Parent.Types)

local Pets: { [string]: Types.PetDef } = {
	CottonCat = { Name = "Gato de Algodão-Doce", Rarity = "Common", Multiplier = 1.5 },
	BearGummy = { Name = "Urso de Goma", Rarity = "Common", Multiplier = 2 },
	LollipopBunny = { Name = "Coelho Pirulito", Rarity = "Uncommon", Multiplier = 3 },
	JellyUnicorn = { Name = "Unicórnio de Gelatina", Rarity = "Rare", Multiplier = 5 },
	ChocolateDragon = { Name = "Dragão de Chocolate", Rarity = "Legendary", Multiplier = 10 },
}

return table.freeze(Pets)
