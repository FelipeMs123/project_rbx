--!strict
-- Areas.luau (ReplicatedStorage.Shared.Logic.Areas)
-- Dono: Squad A. Valida o desbloqueio sem alterar dados nem depender do Roblox.

local Areas = {}

-- Coordenadas em tabelas { X, Y, Z }, sem depender de Vector3 do Roblox.
export type Position = { X: number, Y: number, Z: number }
export type Box = { id: string, min: Position, max: Position }

local function contains(box: Box, position: Position): boolean
	return position.X >= box.min.X
		and position.X <= box.max.X
		and position.Y >= box.min.Y
		and position.Y <= box.max.Y
		and position.Z >= box.min.Z
		and position.Z <= box.max.Z
end

function Areas.lockedAreaAt(boxes: { Box }, unlockedList: { string }, position: Position): string?
	local lockedId: string? = nil
	for _, box in boxes do
		if contains(box, position) then
			if table.find(unlockedList, box.id) then
				return nil
			end
			lockedId = lockedId or box.id
		end
	end
	return lockedId
end

function Areas.lastUnlocked(areasConfig: { [string]: { Order: number } }, unlockedList: { string }): string?
	local lastId: string? = nil
	local lastOrder = -math.huge
	for _, id in unlockedList do
		local area = areasConfig[id]
		if area and area.Order > lastOrder then
			lastId = id
			lastOrder = area.Order
		end
	end
	return lastId
end

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
