--!strict
-- EggHelpers.luau (StarterPlayerScripts.Client.UI.Eggs.EggHelpers)
-- Dono: Squad B. Funções puras auxiliares da UI de Ovos (sem APIs do Roblox, testável no Lune).

export type RarityInfo = {
	Name: string,
	Order: number,
	R: number,
	G: number,
	B: number,
}

export type PetDefLike = {
	Name: string,
	Rarity: string,
	Multiplier: number,
}

export type EggDefLike = {
	Name: string,
	Price: number,
	Currency: string,
	Area: string,
	Weights: { [string]: number },
}

export type PlayerDataLike = {
	Coins: number?,
	Gems: number?,
	UnlockedAreas: { string }?,
	Inventory: { [string]: any }?,
}

export type PetChanceEntry = {
	PetId: string,
	Name: string,
	Rarity: string,
	Multiplier: number,
	Weight: number,
	ChancePercent: number,
}

export type PromptLayout = {
	IsCompact: boolean,
	Scale: number,
	PositionYScale: number,
	WidthScale: number,
	HeightScale: number,
	MinWidth: number,
	MinHeight: number,
	MaxWidth: number,
	MaxHeight: number,
	HeaderHeightScale: number,
	ListTopScale: number,
	ListHeightScale: number,
	BuyHeightScale: number,
	BuyMinHeight: number,
}

local EggHelpers = {}

EggHelpers.Rarities = table.freeze({
	Common = table.freeze({ Name = "Comum", Order = 1, R = 160, G = 174, B = 192 }),
	Uncommon = table.freeze({ Name = "Incomum", Order = 2, R = 72, G = 187, B = 120 }),
	Rare = table.freeze({ Name = "Raro", Order = 3, R = 66, G = 153, B = 225 }),
	Epic = table.freeze({ Name = "Épico", Order = 4, R = 159, G = 122, B = 234 }),
	Legendary = table.freeze({ Name = "Lendário", Order = 5, R = 246, G = 173, B = 85 }),
}) :: { [string]: RarityInfo }

EggHelpers.ErrorMessages = table.freeze({
	INVALID_ARGS = "Ops! Algo deu errado nesse pedido. Tente de novo!",
	RATE_LIMITED = "Calma aí! Você está clicando rápido demais.",
	DATA_NOT_LOADED = "Seus dados ainda estão carregando. Aguarde um segundinho!",
	INTERNAL = "Ops! Deu um probleminha no servidor. Tente de novo!",
	NOT_ENOUGH_COINS = "Moedas insuficientes! Quebre mais doces para juntar.",
	NOT_ENOUGH_GEMS = "Gemas insuficientes! Quebre blocos ou faça Rebirth.",
	NOT_OWNED = "Você não tem esse pet ainda!",
	ALREADY_EQUIPPED = "Esse pet já está equipado!",
	NOT_EQUIPPED = "Esse pet não está equipado.",
	MAX_EQUIPPED = "Você já equipou o máximo de pets!",
	INVENTORY_FULL = "Sua mochila de pets está cheia! (50/50)",
	AREA_LOCKED = "Área bloqueada! Libere essa área antes de comprar este ovo.",
	AREA_NOT_UNLOCKED = "Compre essa área no portão antes de entrar!",
	DAILY_NOT_READY = "Volte amanhã para pegar sua recompensa diária!",
	FUSE_INVALID = "Escolha pets iguais e não equipados para fundir.",
	PURCHASE_FAILED = "A compra não foi concluída. Tente de novo!",
	ALREADY_UNLOCKED = "Essa área já está liberada!",
	UNKNOWN_ITEM = "Esse ovo não foi encontrado!",
	TOO_FAR = "Chegue mais perto do ovo para comprar!",
	NOT_IMPLEMENTED = "Essa função ainda está chegando no jogo!",
}) :: { [string]: string }

local DEFAULT_ERROR_MESSAGE = "Ops! Não deu para comprar agora. Tente de novo!"

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function EggHelpers.getRarityInfo(rarity: string?): RarityInfo
	if type(rarity) == "string" then
		local found = EggHelpers.Rarities[rarity]
		if found then
			return found
		end
	end
	return EggHelpers.Rarities.Common
end

function EggHelpers.translateError(code: string?): string
	if type(code) == "string" then
		local message = EggHelpers.ErrorMessages[code]
		if message then
			return message
		end
	end
	return DEFAULT_ERROR_MESSAGE
end

function EggHelpers.formatShortNumber(value: number): string
	if not isFiniteNumber(value) then
		return "0"
	end
	local negative = value < 0
	local absValue = math.abs(value)
	local formatted: string

	if absValue < 1000 then
		formatted = tostring(math.floor(absValue))
	else
		local suffixes = {
			{ Threshold = 1e12, Suffix = "T" },
			{ Threshold = 1e9, Suffix = "B" },
			{ Threshold = 1e6, Suffix = "M" },
			{ Threshold = 1e3, Suffix = "K" },
		}
		formatted = tostring(math.floor(absValue))
		for _, entry in suffixes do
			if absValue >= entry.Threshold then
				local scaled = math.floor((absValue / entry.Threshold) * 10 + 1e-9) / 10
				local text = string.format("%.1f", scaled)
				text = string.gsub(text, "%.0$", "")
				formatted = `{text}{entry.Suffix}`
				break
			end
		end
	end

	return if negative then `-{formatted}` else formatted
end

function EggHelpers.countInventory(inventory: { [string]: any }?): number
	if type(inventory) ~= "table" then
		return 0
	end
	local count = 0
	for _ in pairs(inventory) do
		count += 1
	end
	return count
end

function EggHelpers.isAreaUnlocked(data: PlayerDataLike?, areaId: string?): boolean
	if type(areaId) ~= "string" or areaId == "" then
		return true
	end
	if type(data) ~= "table" or type(data.UnlockedAreas) ~= "table" then
		return false
	end
	for _, unlocked in data.UnlockedAreas do
		if unlocked == areaId then
			return true
		end
	end
	return false
end

function EggHelpers.canAffordEgg(data: PlayerDataLike?, eggDef: EggDefLike?, eggId: string?): (boolean, string?)
	if eggId ~= nil and (type(eggId) ~= "string" or eggId == "") then
		return false, "UNKNOWN_ITEM"
	end
	if type(eggDef) ~= "table" or not isFiniteNumber(eggDef.Price) or eggDef.Price < 0 then
		return false, "UNKNOWN_ITEM"
	end
	if type(data) ~= "table" then
		return false, "DATA_NOT_LOADED"
	end

	local currency = if eggDef.Currency == "Gems" then "Gems" else "Coins"
	local balance = if currency == "Gems" then data.Gems else data.Coins
	if not isFiniteNumber(balance) then
		balance = 0
	end

	if (balance :: number) < eggDef.Price then
		return false, if currency == "Gems" then "NOT_ENOUGH_GEMS" else "NOT_ENOUGH_COINS"
	end

	return true, nil
end

function EggHelpers.canPurchaseEgg(
	data: PlayerDataLike?,
	eggDef: EggDefLike?,
	maxInventory: number,
	eggId: string?
): (boolean, string?)
	if type(data) ~= "table" then
		return false, "DATA_NOT_LOADED"
	end
	if eggId ~= nil and (type(eggId) ~= "string" or eggId == "") then
		return false, "UNKNOWN_ITEM"
	end
	if type(eggDef) ~= "table" then
		return false, "UNKNOWN_ITEM"
	end
	if not EggHelpers.isAreaUnlocked(data, eggDef.Area) then
		return false, "AREA_LOCKED"
	end
	if
		type(maxInventory) ~= "number"
		or maxInventory ~= maxInventory
		or maxInventory <= 0
		or EggHelpers.countInventory(data.Inventory) >= maxInventory
	then
		return false, "INVENTORY_FULL"
	end
	return EggHelpers.canAffordEgg(data, eggDef, eggId)
end

function EggHelpers.buildPetChances(eggDef: EggDefLike?, petsConfig: { [string]: PetDefLike }?): { PetChanceEntry }
	if type(eggDef) ~= "table" or type(eggDef.Weights) ~= "table" then
		return {}
	end

	local totalWeight = 0
	for _, weight in pairs(eggDef.Weights) do
		if isFiniteNumber(weight) and weight > 0 then
			totalWeight += weight
		end
	end

	if totalWeight <= 0 then
		return {}
	end

	local entries: { PetChanceEntry } = {}
	for petId, weight in pairs(eggDef.Weights) do
		if type(petId) == "string" and isFiniteNumber(weight) and weight > 0 then
			local petDef = if type(petsConfig) == "table" then petsConfig[petId] else nil
			local rawPercent = (weight * 100) / totalWeight
			local roundedPercent = math.floor(rawPercent * 100 + 0.5) / 100
			table.insert(entries, {
				PetId = petId,
				Name = if petDef then petDef.Name else petId,
				Rarity = if petDef then petDef.Rarity else "Common",
				Multiplier = if petDef then petDef.Multiplier else 0,
				Weight = weight,
				ChancePercent = roundedPercent,
			})
		end
	end

	table.sort(entries, function(a: PetChanceEntry, b: PetChanceEntry): boolean
		if a.ChancePercent ~= b.ChancePercent then
			return a.ChancePercent > b.ChancePercent
		end
		if a.Weight ~= b.Weight then
			return a.Weight > b.Weight
		end
		return a.PetId < b.PetId
	end)

	return entries
end

function EggHelpers.getCurrencyName(currency: string?): string
	return if currency == "Gems" then "Gemas" else "Moedas"
end

function EggHelpers.formatPriceText(eggDef: EggDefLike?): string
	if type(eggDef) ~= "table" then
		return "0 Moedas"
	end
	local priceText = EggHelpers.formatShortNumber(eggDef.Price)
	return `{priceText} {EggHelpers.getCurrencyName(eggDef.Currency)}`
end

function EggHelpers.canTriggerPurchase(isStarted: boolean, isPurchasing: boolean, hasOpenModal: boolean): boolean
	return isStarted and not isPurchasing and not hasOpenModal
end

function EggHelpers.computePromptLayout(viewportWidth: number, viewportHeight: number, isTouch: boolean): PromptLayout
	local validW = isFiniteNumber(viewportWidth) and viewportWidth > 0
	local validH = isFiniteNumber(viewportHeight) and viewportHeight > 0
	local width = if validW then viewportWidth else 1280
	local height = if validH then viewportHeight else 720

	local ratio = math.min(width / 1280, height / 720)
	local isCompact = height <= 520 or width <= 720

	if isCompact then
		return {
			IsCompact = true,
			Scale = math.clamp(ratio, 0.80, 1.0),
			PositionYScale = 0.64,
			WidthScale = 0.56,
			HeightScale = 0.36,
			MinWidth = 276,
			MinHeight = 154,
			MaxWidth = 360,
			MaxHeight = 180,
			HeaderHeightScale = 0.25,
			ListTopScale = 0.27,
			ListHeightScale = 0.32,
			BuyHeightScale = 0.36,
			BuyMinHeight = 55,
		}
	end

	return {
		IsCompact = false,
		Scale = math.clamp(ratio, 0.85, 1.25),
		PositionYScale = if isTouch then 0.72 else 0.92,
		WidthScale = 0.44,
		HeightScale = 0.32,
		MinWidth = 310,
		MinHeight = 210,
		MaxWidth = 560,
		MaxHeight = 330,
		HeaderHeightScale = 0.22,
		ListTopScale = 0.25,
		ListHeightScale = 0.44,
		BuyHeightScale = 0.24,
		BuyMinHeight = 52,
	}
end

return EggHelpers
