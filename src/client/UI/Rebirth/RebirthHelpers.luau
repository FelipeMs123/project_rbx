--!strict
-- RebirthHelpers.luau (StarterPlayerScripts.Client.UI.Rebirth.RebirthHelpers)
-- Dono: Squad B. Funções puras auxiliares da UI de Rebirth (sem APIs do Roblox, testável no Lune).

export type RebirthConfigLike = {
	RebirthBaseCost: number,
	RebirthCostGrowth: number,
	RebirthCoinBonus: number,
	RebirthGemReward: number,
}

export type MultiplierPreview = {
	CurrentRebirths: number,
	NextRebirths: number,
	CurrentMultiplier: number,
	NextMultiplier: number,
	GemReward: number,
}

export type ProgressInfo = {
	Ratio: number,
	Percent: number,
	CanRebirth: boolean,
	MissingCoins: number,
}

local DEFAULT_REBIRTH_CONFIG: RebirthConfigLike = table.freeze({
	RebirthBaseCost = 10000,
	RebirthCostGrowth = 2.5,
	RebirthCoinBonus = 0.5,
	RebirthGemReward = 5,
})

local RebirthHelpers = {}

RebirthHelpers.ErrorMessages = table.freeze({
	INVALID_ARGS = "Ops! Algo deu errado nesse pedido. Tente de novo!",
	RATE_LIMITED = "Calma aí! Aguarde um instante antes de tentar de novo.",
	DATA_NOT_LOADED = "Seus dados ainda estão carregando. Aguarde um segundinho!",
	INTERNAL = "Ops! Deu um probleminha no servidor. Tente de novo!",
	NOT_ENOUGH_COINS = "Você ainda não tem moedas suficientes para fazer Rebirth!",
	NOT_ENOUGH_GEMS = "Gemas insuficientes para essa ação.",
	NOT_OWNED = "Você não tem esse item ainda!",
	ALREADY_EQUIPPED = "Esse pet já está equipado!",
	NOT_EQUIPPED = "Esse pet não está equipado.",
	MAX_EQUIPPED = "Você já equipou o máximo de pets!",
	INVENTORY_FULL = "Sua mochila de pets está cheia!",
	AREA_LOCKED = "Essa área ainda está bloqueada!",
	AREA_NOT_UNLOCKED = "Compre essa área no portão antes de entrar!",
	DAILY_NOT_READY = "Volte amanhã para pegar sua recompensa diária!",
	FUSE_INVALID = "Escolha pets iguais e não equipados para fundir.",
	PURCHASE_FAILED = "A compra não foi concluída. Tente de novo!",
	ALREADY_UNLOCKED = "Essa área já está liberada!",
	UNKNOWN_ITEM = "Item não encontrado!",
	TOO_FAR = "Chegue mais perto para fazer isso!",
	NOT_IMPLEMENTED = "Essa função ainda está chegando no jogo!",
}) :: { [string]: string }

local DEFAULT_ERROR_MESSAGE = "Ops! Não foi possível fazer Rebirth agora. Tente de novo!"

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function sanitizeNonNegative(value: any): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	if value <= 0 then
		return 0
	end
	if value == math.huge then
		return math.huge
	end
	return value
end

local function sanitizeFiniteNonNegative(value: any): number
	if not isFiniteNumber(value) or value <= 0 then
		return 0
	end
	return value
end

local function resolveConfig(config: RebirthConfigLike?): RebirthConfigLike
	if type(config) == "table" then
		return config
	end
	return DEFAULT_REBIRTH_CONFIG
end

function RebirthHelpers.translateError(code: string?): string
	if type(code) == "string" then
		local message = RebirthHelpers.ErrorMessages[code]
		if message then
			return message
		end
	end
	return DEFAULT_ERROR_MESSAGE
end

function RebirthHelpers.formatShortNumber(value: number): string
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

function RebirthHelpers.computeCost(rebirths: number, config: RebirthConfigLike?): number
	local cfg = resolveConfig(config)
	local baseCost = sanitizeNonNegative(cfg.RebirthBaseCost)
	local growth = sanitizeNonNegative(cfg.RebirthCostGrowth)
	local safeRebirths = sanitizeNonNegative(rebirths)
	if safeRebirths == math.huge then
		return math.huge
	end
	local wholeRebirths = math.floor(safeRebirths)
	return math.floor(baseCost * (growth ^ wholeRebirths))
end

function RebirthHelpers.computeMultipliers(rebirths: number, config: RebirthConfigLike?): MultiplierPreview
	local cfg = resolveConfig(config)
	local coinBonus = sanitizeFiniteNonNegative(cfg.RebirthCoinBonus)
	local gemReward = sanitizeFiniteNonNegative(cfg.RebirthGemReward)
	local safeRebirths = sanitizeFiniteNonNegative(rebirths)
	local currentRebirths = math.floor(safeRebirths)
	local nextRebirths = currentRebirths + 1

	return {
		CurrentRebirths = currentRebirths,
		NextRebirths = nextRebirths,
		CurrentMultiplier = 1 + currentRebirths * coinBonus,
		NextMultiplier = 1 + nextRebirths * coinBonus,
		GemReward = gemReward,
	}
end

function RebirthHelpers.computeProgress(coins: number, cost: number): ProgressInfo
	local safeCoins = sanitizeFiniteNonNegative(coins)
	local safeCost = sanitizeNonNegative(cost)

	if safeCost <= 0 then
		return {
			Ratio = 1,
			Percent = 100,
			CanRebirth = true,
			MissingCoins = 0,
		}
	end

	local ratio = math.clamp(safeCoins / safeCost, 0, 1)
	local canRebirth = safeCoins >= safeCost
	local missingCoins = if canRebirth then 0 else math.max(0, safeCost - safeCoins)

	return {
		Ratio = ratio,
		Percent = math.floor(ratio * 100),
		CanRebirth = canRebirth,
		MissingCoins = missingCoins,
	}
end

return RebirthHelpers
