--!nocheck
-- EggHelpers.spec.luau (testes Lune de StarterPlayerScripts.Client.UI.Eggs.EggHelpers)
-- Dono: Squad B. Cobre validação de compra, chances de pets, formatação e tradução de erros.

local EggHelpers = require("../src/client/UI/Eggs/EggHelpers")
local ErrorCodes = require("../src/shared/ErrorCodes")
local GameConfig = require("../src/shared/Config/Game")

local PetsConfig = {
	CottonCat = { Name = "Gato de Algodão-Doce", Rarity = "Common", Multiplier = 1.5 },
	BearGummy = { Name = "Urso de Goma", Rarity = "Common", Multiplier = 2 },
	LollipopBunny = { Name = "Coelho Pirulito", Rarity = "Uncommon", Multiplier = 3 },
	JellyUnicorn = { Name = "Unicórnio de Gelatina", Rarity = "Rare", Multiplier = 5 },
	ChocolateDragon = { Name = "Dragão de Chocolate", Rarity = "Legendary", Multiplier = 10 },
}

local EggsConfig = {
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

local function makeFullInventory(count: number): { [string]: any }
	local inv = {}
	for i = 1, count do
		inv[`pet-{i}`] = { Id = "CottonCat" }
	end
	return inv
end

return function(t)
	t.test("traduz todos os códigos de erro do ErrorCodes e trata entrada inválida", function()
		for _, code in pairs(ErrorCodes) do
			local translated = EggHelpers.translateError(code)
			t.ok(type(translated) == "string" and #translated > 0, `faltou tradução para {code}`)
		end

		t.ok(string.find(EggHelpers.translateError(ErrorCodes.UNKNOWN_ITEM), "ovo", 1, true) ~= nil)
		t.ok(string.find(EggHelpers.translateError(ErrorCodes.AREA_LOCKED), "Área", 1, true) ~= nil)
		t.ok(string.find(EggHelpers.translateError(ErrorCodes.NOT_ENOUGH_COINS), "Moedas", 1, true) ~= nil)
		t.ok(string.find(EggHelpers.translateError(ErrorCodes.INVENTORY_FULL), "cheia", 1, true) ~= nil)
		t.ok(string.find(EggHelpers.translateError(ErrorCodes.TOO_FAR), "perto", 1, true) ~= nil)
		t.ok(string.find(EggHelpers.translateError(ErrorCodes.RATE_LIMITED), "rápido", 1, true) ~= nil)

		local fallbackNil = EggHelpers.translateError(nil)
		local fallbackUnknown = EggHelpers.translateError("NON_EXISTENT_CODE")
		t.eq(fallbackNil, fallbackUnknown)
		t.ok(#fallbackNil > 0)
	end)

	t.test("formata números curtos com sufixos e trata NaN/infinito/negativo", function()
		t.eq(EggHelpers.formatShortNumber(0), "0")
		t.eq(EggHelpers.formatShortNumber(999), "999")
		t.eq(EggHelpers.formatShortNumber(1000), "1K")
		t.eq(EggHelpers.formatShortNumber(2500), "2.5K")
		t.eq(EggHelpers.formatShortNumber(1500000), "1.5M")
		t.eq(EggHelpers.formatShortNumber(3000000000), "3B")
		t.eq(EggHelpers.formatShortNumber(1200000000000), "1.2T")
		t.eq(EggHelpers.formatShortNumber(-1500), "-1.5K")
		t.eq(EggHelpers.formatShortNumber(0 / 0), "0")
		t.eq(EggHelpers.formatShortNumber(math.huge), "0")
		t.eq(EggHelpers.formatShortNumber(-math.huge), "0")
	end)

	t.test("valida compra de ovos reais (sucesso e erros do contrato)", function()
		local baseData = {
			Coins = 100,
			Gems = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {},
		}

		local ok, err = EggHelpers.canPurchaseEgg(baseData, EggsConfig.CandyEgg, GameConfig.MaxInventory, "CandyEgg")
		t.eq(ok, true)
		t.eq(err, nil)

		ok, err = EggHelpers.canPurchaseEgg(
			{ Coins = 99, Gems = 0, UnlockedAreas = { "CandyPlaza" }, Inventory = {} },
			EggsConfig.CandyEgg,
			GameConfig.MaxInventory,
			"CandyEgg"
		)
		t.eq(ok, false)
		t.eq(err, ErrorCodes.NOT_ENOUGH_COINS)

		ok, err = EggHelpers.canPurchaseEgg(
			{ Coins = 5000, Gems = 0, UnlockedAreas = { "CandyPlaza" }, Inventory = {} },
			EggsConfig.ChocolateEgg,
			GameConfig.MaxInventory,
			"ChocolateEgg"
		)
		t.eq(ok, false)
		t.eq(err, ErrorCodes.AREA_LOCKED)

		ok, err = EggHelpers.canPurchaseEgg(
			{ Coins = 2500, Gems = 0, UnlockedAreas = { "CandyPlaza", "ChocolateFalls" }, Inventory = {} },
			EggsConfig.ChocolateEgg,
			GameConfig.MaxInventory,
			"ChocolateEgg"
		)
		t.eq(ok, true)
		t.eq(err, nil)

		ok, err = EggHelpers.canPurchaseEgg({
			Coins = 5000,
			Gems = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = makeFullInventory(GameConfig.MaxInventory),
		}, EggsConfig.CandyEgg, GameConfig.MaxInventory, "CandyEgg")
		t.eq(ok, false)
		t.eq(err, ErrorCodes.INVENTORY_FULL)
	end)

	t.test("valida ovo com Gemas e casos inválidos (nil, NaN, negativo, eggId vazio)", function()
		local gemEgg = {
			Name = "Ovo de Gema",
			Price = 50,
			Currency = "Gems",
			Area = "CandyPlaza",
			Weights = { CottonCat = 100 },
		}

		local ok, err = EggHelpers.canPurchaseEgg(
			{ Coins = 0, Gems = 49, UnlockedAreas = { "CandyPlaza" }, Inventory = {} },
			gemEgg,
			GameConfig.MaxInventory,
			"GemEgg"
		)
		t.eq(ok, false)
		t.eq(err, ErrorCodes.NOT_ENOUGH_GEMS)

		ok, err = EggHelpers.canPurchaseEgg(
			{ Coins = 0, Gems = 50, UnlockedAreas = { "CandyPlaza" }, Inventory = {} },
			gemEgg,
			GameConfig.MaxInventory,
			"GemEgg"
		)
		t.eq(ok, true)
		t.eq(err, nil)

		ok, err = EggHelpers.canPurchaseEgg(nil, EggsConfig.CandyEgg, GameConfig.MaxInventory, "CandyEgg")
		t.eq(ok, false)
		t.eq(err, ErrorCodes.DATA_NOT_LOADED)

		ok, err = EggHelpers.canPurchaseEgg({ Coins = 1000, UnlockedAreas = { "CandyPlaza" } }, nil, 50, "Missing")
		t.eq(ok, false)
		t.eq(err, ErrorCodes.UNKNOWN_ITEM)

		ok, err =
			EggHelpers.canPurchaseEgg({ Coins = 1000, UnlockedAreas = { "CandyPlaza" } }, EggsConfig.CandyEgg, 50, "")
		t.eq(ok, false)
		t.eq(err, ErrorCodes.UNKNOWN_ITEM)

		ok, err = EggHelpers.canPurchaseEgg(
			{ Coins = 1000, UnlockedAreas = { "CandyPlaza" } },
			{ Name = "Bad", Price = -10, Currency = "Coins", Area = "CandyPlaza", Weights = {} },
			50,
			"BadEgg"
		)
		t.eq(ok, false)
		t.eq(err, ErrorCodes.UNKNOWN_ITEM)

		ok, err = EggHelpers.canPurchaseEgg(
			{ Coins = 1000, UnlockedAreas = { "CandyPlaza" } },
			{ Name = "NaN", Price = 0 / 0, Currency = "Coins", Area = "CandyPlaza", Weights = {} },
			50,
			"NaNEgg"
		)
		t.eq(ok, false)
		t.eq(err, ErrorCodes.UNKNOWN_ITEM)

		ok, err = EggHelpers.canPurchaseEgg(
			{ Coins = 0 / 0, Gems = nil, UnlockedAreas = { "CandyPlaza" }, Inventory = {} },
			EggsConfig.CandyEgg,
			50,
			"CandyEgg"
		)
		t.eq(ok, false)
		t.eq(err, ErrorCodes.NOT_ENOUGH_COINS)

		ok, err = EggHelpers.canPurchaseEgg(
			{ Coins = -50, UnlockedAreas = { "CandyPlaza" }, Inventory = {} },
			EggsConfig.CandyEgg,
			50,
			"CandyEgg"
		)
		t.eq(ok, false)
		t.eq(err, ErrorCodes.NOT_ENOUGH_COINS)

		ok, err = EggHelpers.canPurchaseEgg(
			{ Coins = 1000, UnlockedAreas = { "CandyPlaza" }, Inventory = {} },
			EggsConfig.CandyEgg,
			0 / 0,
			"CandyEgg"
		)
		t.eq(ok, false)
		t.eq(err, ErrorCodes.INVENTORY_FULL)

		ok, err = EggHelpers.canPurchaseEgg(
			{ Coins = 1000, UnlockedAreas = { "CandyPlaza" }, Inventory = {} },
			EggsConfig.CandyEgg,
			-1,
			"CandyEgg"
		)
		t.eq(ok, false)
		t.eq(err, ErrorCodes.INVENTORY_FULL)
	end)

	t.test("calcula e ordena chances dos pets e resolve raridades", function()
		local chances = EggHelpers.buildPetChances(EggsConfig.CandyEgg, PetsConfig)
		t.eq(#chances, 3)
		t.eq(chances[1].PetId, "CottonCat")
		t.eq(chances[1].ChancePercent, 60)
		t.eq(chances[2].PetId, "BearGummy")
		t.eq(chances[2].ChancePercent, 30)
		t.eq(chances[3].PetId, "LollipopBunny")
		t.eq(chances[3].ChancePercent, 10)
		t.eq(chances[3].Name, PetsConfig.LollipopBunny.Name)

		local chocolateChances = EggHelpers.buildPetChances(EggsConfig.ChocolateEgg, PetsConfig)
		t.eq(#chocolateChances, 4)
		t.eq(chocolateChances[1].PetId, "BearGummy")
		t.eq(chocolateChances[4].PetId, "ChocolateDragon")
		t.eq(chocolateChances[4].ChancePercent, 1)

		local filtered = EggHelpers.buildPetChances({
			Name = "Test",
			Price = 10,
			Currency = "Coins",
			Area = "CandyPlaza",
			Weights = { CottonCat = 10, BadZero = 0, BadNeg = -5, BadNaN = 0 / 0, BadInf = math.huge },
		}, PetsConfig)
		t.eq(#filtered, 1)
		t.eq(filtered[1].PetId, "CottonCat")
		t.eq(filtered[1].ChancePercent, 100)

		t.eq(#EggHelpers.buildPetChances(nil, PetsConfig), 0)
		t.eq(EggHelpers.getRarityInfo("Legendary").Name, "Lendário")
		t.eq(EggHelpers.getRarityInfo("UnknownRarity").Name, "Comum")
		t.eq(EggHelpers.getRarityInfo(nil).Name, "Comum")
	end)
end
