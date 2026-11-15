--!strict
-- Monetization.luau (ReplicatedStorage.Shared.Config.Monetization)
-- Dono: Squad B. preencher PassId/ProductId reais do Creator Hub.

export type GamePassDef = {
	Id: number,
	PriceRobux: number,
	ClicksPerSecond: number?,
	Multiplier: number?,
	BonusSlots: number?,
}
export type DevProductDef = {
	Id: number,
	PriceRobux: number,
	Gems: number?,
	Multiplier: number?,
	DurationSeconds: number?,
}
export type MonetizationConfig = {
	GamePasses: { [string]: GamePassDef },
	DevProducts: { [string]: DevProductDef },
}

local Monetization: MonetizationConfig = {
	GamePasses = {
		AutoClicker = { Id = 0, PriceRobux = 49, ClicksPerSecond = 8 },
		DoubleCoins = { Id = 0, PriceRobux = 149, Multiplier = 2 },
		ExtraPetSlot = { Id = 0, PriceRobux = 199, BonusSlots = 1 },
	},
	DevProducts = {
		GemsSmall = { Id = 0, PriceRobux = 29, Gems = 25 },
		GemsLarge = { Id = 0, PriceRobux = 99, Gems = 120 },
		CoinBoost15m = { Id = 0, PriceRobux = 25, Multiplier = 2, DurationSeconds = 900 },
	},
}

return table.freeze(Monetization)
