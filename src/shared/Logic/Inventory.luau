--!strict
-- Inventory.luau (ReplicatedStorage.Shared.Logic.Inventory)
-- Dono: Squad B. Valida inventário/equipamento/fusão e calcula bônus de pets sem Roblox.

local Inventory = {}

export type PetInstance = { Id: string, Variant: string? }
export type PlayerData = { Inventory: { [string]: PetInstance }, Equipped: { string } }
export type PetDefinition = { Multiplier: number, Name: string?, Rarity: string? }
export type FusionConfig = {
	RequiredCount: number,
	GoldenMultiplier: number?,
	AllowRefuseGolden: boolean?,
	GemCostByRarity: { [string]: number }?,
}
export type EquippedToken = {
	petId: string,
	variant: string?,
}
export type FusableGroup = {
	petId: string,
	def: PetDefinition,
	uuids: { string },
	batchUuids: { string },
	count: number,
	requiredCount: number,
	gemCost: number,
}

local DEFAULT_GOLDEN_MULTIPLIER = 2.0
local DEFAULT_REQUIRED_COUNT = 5
local VALID_VARIANTS: { [string]: boolean } = {
	Golden = true,
}

function Inventory.isValidVariant(variant: any): boolean
	return type(variant) == "string" and VALID_VARIANTS[variant] == true
end

function Inventory.formatEquippedToken(petId: string, variant: string?): string
	if Inventory.isValidVariant(variant) then
		return `{petId}:{variant}`
	end
	return petId
end

function Inventory.parseEquippedAttribute(raw: any, petsConfig: { [string]: PetDefinition }): { EquippedToken }
	if type(raw) ~= "string" or raw == "" or type(petsConfig) ~= "table" then
		return {}
	end
	local result: { EquippedToken } = {}
	for _, token in string.split(raw, ",") do
		local trimmed = string.gsub(token, "^%s*(.-)%s*$", "%1")
		if trimmed ~= "" then
			local colonPos = string.find(trimmed, ":", 1, true)
			local petId = trimmed
			local variant: string? = nil
			if colonPos ~= nil then
				petId = string.gsub(string.sub(trimmed, 1, colonPos - 1), "^%s*(.-)%s*$", "%1")
				local rawVariant = string.gsub(string.sub(trimmed, colonPos + 1), "^%s*(.-)%s*$", "%1")
				if VALID_VARIANTS[rawVariant] then
					variant = rawVariant
				end
			end
			if petId ~= "" and petsConfig[petId] ~= nil then
				table.insert(result, {
					petId = petId,
					variant = variant,
				})
			end
		end
	end
	return result
end

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

function Inventory.petMultiplier(
	pet: PetInstance?,
	petsConfig: { [string]: PetDefinition },
	fusionConfig: FusionConfig?
): number
	if pet == nil then
		return 0
	end
	local definition = petsConfig[pet.Id]
	if definition == nil then
		return 0
	end
	local goldenMultiplier = if fusionConfig ~= nil and type(fusionConfig.GoldenMultiplier) == "number"
		then fusionConfig.GoldenMultiplier
		else DEFAULT_GOLDEN_MULTIPLIER
	local variantFactor = if pet.Variant == "Golden" then goldenMultiplier else 1
	return definition.Multiplier * variantFactor
end

function Inventory.bonus(data: PlayerData, petsConfig: { [string]: PetDefinition }, fusionConfig: FusionConfig?): number
	local total = 0
	for _, uuid in data.Equipped do
		local pet = data.Inventory[uuid]
		total += Inventory.petMultiplier(pet, petsConfig, fusionConfig)
	end
	return total
end

function Inventory.canFuse(
	data: PlayerData,
	uuids: any,
	petsConfig: { [string]: PetDefinition },
	fusionConfig: FusionConfig
): (boolean, string?, string?, PetDefinition?)
	if type(data) ~= "table" or type(data.Inventory) ~= "table" or type(data.Equipped) ~= "table" then
		return false, "FUSE_INVALID", nil, nil
	end
	if type(petsConfig) ~= "table" or type(fusionConfig) ~= "table" then
		return false, "FUSE_INVALID", nil, nil
	end

	local requiredCount = fusionConfig.RequiredCount
	if type(requiredCount) ~= "number" or requiredCount < 1 or math.floor(requiredCount) ~= requiredCount then
		return false, "FUSE_INVALID", nil, nil
	end
	if type(uuids) ~= "table" then
		return false, "FUSE_INVALID", nil, nil
	end

	local allowRefuseGolden = fusionConfig.AllowRefuseGolden == true
	local equippedSet: { [string]: boolean } = {}
	for _, equippedUuid in data.Equipped do
		equippedSet[equippedUuid] = true
	end

	-- Valida array estrito (somente chaves inteiras 1..RequiredCount, sem buracos ou chaves extras).
	local pairCount = 0
	for key in pairs(uuids) do
		if type(key) ~= "number" or key < 1 or key > requiredCount or math.floor(key) ~= key then
			return false, "FUSE_INVALID", nil, nil
		end
		pairCount += 1
	end
	if pairCount ~= requiredCount or #uuids ~= requiredCount then
		return false, "FUSE_INVALID", nil, nil
	end

	local seen: { [string]: boolean } = {}
	local targetPetId: string? = nil
	local targetDef: PetDefinition? = nil

	for index = 1, requiredCount do
		local uuid = uuids[index]
		if type(uuid) ~= "string" or #uuid < 1 or #uuid > 64 or seen[uuid] then
			return false, "FUSE_INVALID", nil, nil
		end
		seen[uuid] = true

		if equippedSet[uuid] then
			return false, "FUSE_INVALID", nil, nil
		end

		local pet = data.Inventory[uuid]
		if type(pet) ~= "table" or type(pet.Id) ~= "string" then
			return false, "FUSE_INVALID", nil, nil
		end

		local petDef = petsConfig[pet.Id]
		if petDef == nil then
			return false, "FUSE_INVALID", nil, nil
		end

		if not allowRefuseGolden and pet.Variant ~= nil then
			return false, "FUSE_INVALID", nil, nil
		end

		if targetPetId == nil then
			targetPetId = pet.Id
			targetDef = petDef
		elseif pet.Id ~= targetPetId then
			return false, "FUSE_INVALID", nil, nil
		end
	end

	return true, nil, targetPetId, targetDef
end

function Inventory.getFusableGroups(
	data: PlayerData?,
	petsConfig: { [string]: PetDefinition },
	fusionConfig: FusionConfig?
): { FusableGroup }
	if type(data) ~= "table" or type(data.Inventory) ~= "table" or type(petsConfig) ~= "table" then
		return {}
	end

	local requiredCount = if fusionConfig ~= nil
			and type(fusionConfig.RequiredCount) == "number"
			and fusionConfig.RequiredCount >= 1
		then math.floor(fusionConfig.RequiredCount)
		else DEFAULT_REQUIRED_COUNT
	local allowRefuseGolden = fusionConfig ~= nil and fusionConfig.AllowRefuseGolden == true

	local equippedSet: { [string]: boolean } = {}
	if type(data.Equipped) == "table" then
		for _, uuid in data.Equipped do
			equippedSet[uuid] = true
		end
	end

	local byPetId: { [string]: { string } } = {}
	for uuid, pet in data.Inventory do
		if type(uuid) == "string" and type(pet) == "table" and type(pet.Id) == "string" then
			if petsConfig[pet.Id] ~= nil and not equippedSet[uuid] and (allowRefuseGolden or pet.Variant == nil) then
				local list = byPetId[pet.Id]
				if list == nil then
					list = {}
					byPetId[pet.Id] = list
				end
				table.insert(list, uuid)
			end
		end
	end

	local groups: { FusableGroup } = {}
	for petId, uuids in byPetId do
		if #uuids >= requiredCount then
			table.sort(uuids)
			local batch: { string } = {}
			for i = 1, requiredCount do
				table.insert(batch, uuids[i])
			end
			local def = petsConfig[petId]
			local gemCost = 0
			if fusionConfig ~= nil and fusionConfig.GemCostByRarity ~= nil and type(def.Rarity) == "string" then
				local rawCost = fusionConfig.GemCostByRarity[def.Rarity]
				if type(rawCost) == "number" then
					gemCost = rawCost
				end
			end
			table.insert(groups, {
				petId = petId,
				def = def,
				uuids = uuids,
				batchUuids = batch,
				count = #uuids,
				requiredCount = requiredCount,
				gemCost = gemCost,
			})
		end
	end

	table.sort(groups, function(a: FusableGroup, b: FusableGroup): boolean
		if a.def.Multiplier ~= b.def.Multiplier then
			return a.def.Multiplier > b.def.Multiplier
		end
		return a.petId < b.petId
	end)

	return groups
end

return Inventory
