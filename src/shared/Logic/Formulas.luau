--!strict
-- Formulas.luau (ReplicatedStorage.Shared.Logic.Formulas)
-- Dono: Squad A. Dano e divisão pura de recompensas dos blocos.

local Formulas = {}

export type Hit = { key: any, damage: number }
export type Reward = { coins: number, gems: number }

function Formulas.damage(baseDamage: number, petBonus: number): number
	return baseDamage + petBonus
end

function Formulas.splitReward(coins: number, gems: number, maxHp: number, damageLog: { Hit }): { [any]: Reward }
	local rewards: { [any]: Reward } = {}
	if maxHp ~= maxHp or maxHp <= 0 or maxHp == math.huge then
		return rewards
	end
	local totals: { [any]: number } = {}
	local lastHit: { [any]: number } = {}
	local remaining = maxHp
	for index, hit in damageLog do
		if remaining <= 0 then
			break
		end
		if hit.damage == hit.damage and hit.damage > 0 then
			local effective = math.min(hit.damage, remaining)
			totals[hit.key] = (totals[hit.key] or 0) + effective
			lastHit[hit.key] = index
			remaining -= effective
		end
	end
	local winner: any = nil
	local bestDamage, latest = 0, 0
	for key, total in totals do
		rewards[key] = { coins = math.floor(coins * total / maxHp), gems = 0 }
		if total > bestDamage or (total == bestDamage and lastHit[key] > latest) then
			winner, bestDamage, latest = key, total, lastHit[key]
		end
	end
	if gems > 0 and winner ~= nil then
		rewards[winner].gems = gems
	end
	return rewards
end

return Formulas
