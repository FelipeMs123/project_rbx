--!strict
-- Areas.luau (ReplicatedStorage.Shared.Logic.Areas)
-- Dono: Squad A. Valida o desbloqueio sem alterar dados nem depender do Roblox.

local Areas = {}

function Areas.canUnlock(
	areasConfig: { [string]: { Order: number, Price: number } },
	unlockedList: { string },
	areaId: string,
	coins: number
): (boolean, string?)
	local area = areasConfig[areaId]
	if area == nil then
		return false, "UNKNOWN_ITEM"
	end
	if table.find(unlockedList, areaId) then
		return false, "ALREADY_UNLOCKED"
	end
	if area.Order > 1 then
		local hasPrevious = false
		for previousId, previous in areasConfig do
			if previous.Order == area.Order - 1 and table.find(unlockedList, previousId) then
				hasPrevious = true
				break
			end
		end
		if not hasPrevious then
			return false, "AREA_LOCKED"
		end
	end
	if coins < area.Price then
		return false, "NOT_ENOUGH_COINS"
	end
	return true, nil
end

return Areas
