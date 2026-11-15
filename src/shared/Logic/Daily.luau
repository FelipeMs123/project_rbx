--!strict
-- Daily.luau (ReplicatedStorage.Shared.Logic.Daily)
-- Dono: Squad A. Calcula a sequência e as recompensas diárias sem Roblox.

export type DailyState = { LastClaimDay: number, Streak: number }
export type DailyReward = { Day: number, Coins: number, Gems: number, Special: boolean? }

local Daily = {}

function Daily.dayIndex(nowSeconds: number): number
	return math.floor(nowSeconds / 86400)
end

function Daily.evaluate(state: DailyState, today: number, daysCount: number): (boolean, number?)
	if state.LastClaimDay == 0 then
		return true, 1
	end

	local diff = today - state.LastClaimDay
	if diff <= 0 then
		return false, nil
	end

	local streak = state.Streak
	if streak ~= streak or streak < 1 or streak > daysCount or streak % 1 ~= 0 then
		streak = 0
	end
	if diff == 1 then
		return true, if streak >= daysCount then 1 else streak + 1
	elseif diff == 2 then
		return true, math.max(1, streak - 1)
	end
	return true, 1
end

function Daily.reward(days: { DailyReward }, streak: number): DailyReward?
	return days[streak]
end

function Daily.secondsUntilNext(nowSeconds: number): number
	return 86400 - (nowSeconds % 86400)
end

return Daily
