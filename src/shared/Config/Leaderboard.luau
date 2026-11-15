--!strict
-- Leaderboard.luau (ReplicatedStorage.Shared.Config.Leaderboard)
-- Dono: Squad B. configuração do ranking global.

export type LeaderboardConfig = { DataStoreName: string, TopCount: number, RefreshSeconds: number }

local Leaderboard: LeaderboardConfig = {
	DataStoreName = "GlobalRebirths_v1",
	TopCount = 10,
	RefreshSeconds = 60,
}

return table.freeze(Leaderboard)
