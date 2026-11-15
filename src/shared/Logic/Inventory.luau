--!strict
-- Inventory.luau (ReplicatedStorage.Shared.Logic.Inventory)
-- Dono: Squad B. Valida inventário/equipamento e calcula bônus de pets sem Roblox.

local Inventory = {}

type PetInstance = { Id: string }
type PlayerData = { Inventory: { [string]: PetInstance }, Equipped: { string } }
type PetDefinition = { Multiplier: number }

function Inventory.count(data: PlayerData): number
	local total = 0
	for _ in data.Inventory do
		total += 1
	end
	return total
end

function Inventory.canAdd(data: PlayerData, maxInventory: number): (boolean, string?)
	if maxInventory <= 0 or Inventory.count(data) >= maxInventory then
		return false, "INVENTORY_FULL"
	end
	return true, nil
end

function Inventory.isEquipped(data: PlayerData, uuid: string): boolean
	return table.find(data.Equipped, uuid) ~= nil
end

function Inventory.canEquip(data: PlayerData, uuid: string, maxEquipped: number): (boolean, string?)
	if type(uuid) ~= "string" or #uuid < 1 or #uuid > 64 then
		return false, "INVALID_ARGS"
	end
	if data.Inventory[uuid] == nil then
		return false, "NOT_OWNED"
	end
	if Inventory.isEquipped(data, uuid) then
		return false, "ALREADY_EQUIPPED"
	end
	if #data.Equipped >= maxEquipped then
		return false, "MAX_EQUIPPED"
	end
	return true, nil
end

function Inventory.canUnequip(data: PlayerData, uuid: string): (boolean, string?)
	if type(uuid) ~= "string" or #uuid < 1 or #uuid > 64 then
		return false, "INVALID_ARGS"
	end
	if data.Inventory[uuid] == nil then
		return false, "NOT_OWNED"
	end
	if not Inventory.isEquipped(data, uuid) then
		return false, "NOT_EQUIPPED"
	end
	return true, nil
end

function Inventory.bonus(data: PlayerData, petsConfig: { [string]: PetDefinition }): number
	local total = 0
	for _, uuid in data.Equipped do
		local pet = data.Inventory[uuid]
		local definition = if pet ~= nil then petsConfig[pet.Id] else nil
		if definition ~= nil then
			total += definition.Multiplier
		end
	end
	return total
end

return Inventory
