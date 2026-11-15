--!strict
-- Rebirth.luau (ReplicatedStorage.Shared.Logic.Rebirth)
-- Dono: Squad B. Calcula custo e valida saldo para rebirth sem Roblox.

local Rebirth = {}

function Rebirth.cost(rebirths: number, baseCost: number, growth: number): number
	local count = if rebirths ~= rebirths or rebirths < 0 then 0 else rebirths
	return math.floor(baseCost * (growth ^ math.max(0, count)))
end

function Rebirth.canRebirth(coins: number, rebirths: number, baseCost: number, growth: number): (boolean, string?)
	if type(coins) ~= "number" or coins ~= coins or coins == math.huge or coins == -math.huge then
		return false, "NOT_ENOUGH_COINS"
	end
	if coins < Rebirth.cost(rebirths, baseCost, growth) then
		return false, "NOT_ENOUGH_COINS"
	end
	return true, nil
end

return Rebirth
