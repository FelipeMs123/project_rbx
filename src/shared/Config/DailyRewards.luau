--!strict
-- DailyRewards.luau (ReplicatedStorage.Shared.Config.DailyRewards)
-- Dono: Squad A. recompensas base de 7 dias.

export type DailyReward = { Day: number, Coins: number, Gems: number, Special: boolean? }
export type DailyRewardsConfig = {
	ResetOnMissedDays: number,
	Days: { DailyReward },
}

local DailyRewards: DailyRewardsConfig = {
	-- Moedas sobem com o rebirth porque o DailyService paga por EconomyService.AddCoins; gemas são fixas.
	ResetOnMissedDays = 2, -- 1 dia perdido volta 1 passo; 2+ dias zera
	Days = {
		{ Day = 1, Coins = 75, Gems = 2 },
		{ Day = 2, Coins = 150, Gems = 3 },
		{ Day = 3, Coins = 300, Gems = 5 },
		{ Day = 4, Coins = 500, Gems = 8 },
		{ Day = 5, Coins = 800, Gems = 12 },
		{ Day = 6, Coins = 1200, Gems = 15 },
		{ Day = 7, Coins = 2500, Gems = 30, Special = true },
	},
}

return table.freeze(DailyRewards)
