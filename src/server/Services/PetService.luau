--!strict
-- PetService.luau (ServerScriptService.Server.Services.PetService)
-- Dono: Squad B. Gerencia inventário de pets, equipamento, bônus de dano e atributo EquippedPets.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local FusionConfig = require(Shared.Config.Fusion)
local GameConfig = require(Shared.Config.Game)
local PetsConfig = require(Shared.Config.Pets)
local ErrorCodes = require(Shared.ErrorCodes)
local Inventory = require(Shared.Logic.Inventory)
local Types = require(Shared.Types)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local PET_REMOTE_RATE = 8
local PET_REMOTE_BURST = 8
local FUSE_REMOTE_RATE = 2
local FUSE_REMOTE_BURST = 3

local PetService = {}

local initializedPlayers: { [Player]: boolean } = {}

local function isValidUuid(value: any): boolean
	return typeof(value) == "string" and #value >= 1 and #value <= 64
end

local function buildEquippedAttribute(data: Types.PlayerData): string
	local tokens: { string } = {}
	for _, uuid in data.Equipped do
		local pet = data.Inventory[uuid]
		if pet ~= nil and PetsConfig[pet.Id] ~= nil then
			table.insert(tokens, Inventory.formatEquippedToken(pet.Id, pet.Variant))
		end
	end
	return table.concat(tokens, ",")
end

local function syncEquippedAttribute(player: Player, data: Types.PlayerData)
	local nextValue = buildEquippedAttribute(data)
	if player:GetAttribute("EquippedPets") ~= nextValue then
		player:SetAttribute("EquippedPets", nextValue)
	end
end

local function sanitizePlayerData(player: Player, data: Types.PlayerData)
	local rawInventory: { [any]: any } = if type(data.Inventory) == "table" then data.Inventory else {}
	local rawEquipped: { any } = if type(data.Equipped) == "table" then data.Equipped else {}

	local cleanInventory: { [string]: Types.PetInstance } = {}
	local inventoryChanged = type(data.Inventory) ~= "table"

	for uuid, pet in rawInventory do
		if isValidUuid(uuid) and type(pet) == "table" and type(pet.Id) == "string" and PetsConfig[pet.Id] ~= nil then
			local variant: string? = nil
			if pet.Variant ~= nil then
				if Inventory.isValidVariant(pet.Variant) then
					variant = pet.Variant
				else
					inventoryChanged = true
				end
			end
			cleanInventory[uuid] = if variant ~= nil then { Id = pet.Id, Variant = variant } else { Id = pet.Id }
		else
			inventoryChanged = true
		end
	end

	local cleanEquipped: { string } = {}
	local seenEquipped: { [string]: boolean } = {}
	local equippedChanged = type(data.Equipped) ~= "table"
	local rawEquippedCount = 0

	for index, uuid in rawEquipped do
		rawEquippedCount += 1
		if
			type(index) == "number"
			and isValidUuid(uuid)
			and cleanInventory[uuid] ~= nil
			and not seenEquipped[uuid]
			and #cleanEquipped < GameConfig.MaxEquipped
		then
			seenEquipped[uuid] = true
			table.insert(cleanEquipped, uuid)
		else
			equippedChanged = true
		end
	end

	if rawEquippedCount ~= #cleanEquipped then
		equippedChanged = true
	end

	if inventoryChanged then
		DataService.Set(player, "Inventory", cleanInventory)
	end
	if equippedChanged then
		DataService.Set(player, "Equipped", cleanEquipped)
	end

	local currentData = DataService.Get(player) or data
	syncEquippedAttribute(player, currentData)
end

local function onProfileLoaded(player: Player, data: Types.PlayerData)
	if player.Parent ~= Players then
		return
	end
	initializedPlayers[player] = true
	sanitizePlayerData(player, data)
end

local function onDataChanged(player: Player, key: string, _value: any)
	if key ~= "Equipped" and key ~= "Inventory" then
		return
	end
	local data = DataService.Get(player)
	if data ~= nil then
		syncEquippedAttribute(player, data)
	end
end

local function equipPet(player: Player, uuid: any): Types.Result
	if not isValidUuid(uuid) then
		return { ok = false, err = ErrorCodes.INVALID_ARGS }
	end
	local data = DataService.Get(player)
	if data == nil or player.Parent ~= Players then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end
	local canEquip, equipErr = Inventory.canEquip(data, uuid, GameConfig.MaxEquipped)
	if not canEquip then
		return { ok = false, err = equipErr }
	end
	local pet = data.Inventory[uuid]
	if pet == nil or PetsConfig[pet.Id] == nil then
		return { ok = false, err = ErrorCodes.UNKNOWN_ITEM }
	end
	local updated = DataService.Update(player, "Equipped", function(equipped: { string })
		table.insert(equipped, uuid)
		return equipped
	end)
	if updated == nil then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end
	local currentData = DataService.Get(player) or data
	syncEquippedAttribute(player, currentData)
	return { ok = true, data = { uuid = uuid } }
end

local function unequipPet(player: Player, uuid: any): Types.Result
	if not isValidUuid(uuid) then
		return { ok = false, err = ErrorCodes.INVALID_ARGS }
	end
	local data = DataService.Get(player)
	if data == nil or player.Parent ~= Players then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end
	local canUnequip, unequipErr = Inventory.canUnequip(data, uuid)
	if not canUnequip then
		return { ok = false, err = unequipErr }
	end
	local updated = DataService.Update(player, "Equipped", function(equipped: { string })
		for index = #equipped, 1, -1 do
			if equipped[index] == uuid then
				table.remove(equipped, index)
			end
		end
		return equipped
	end)
	if updated == nil then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end
	local currentData = DataService.Get(player) or data
	syncEquippedAttribute(player, currentData)
	return { ok = true, data = { uuid = uuid } }
end

local function fusePets(player: Player, uuids: any): Types.Result
	if player.Parent ~= Players or not DataService.IsLoaded(player) then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end
	local data = DataService.Get(player)
	if data == nil then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end

	local canFuse, fuseErr, petId, petDef = Inventory.canFuse(data, uuids, PetsConfig :: any, FusionConfig :: any)
	if not canFuse or petId == nil or petDef == nil then
		return { ok = false, err = fuseErr or ErrorCodes.FUSE_INVALID }
	end

	local rarity = petDef.Rarity
	local gemCost = if type(rarity) == "string" then FusionConfig.GemCostByRarity[rarity] else nil
	if type(gemCost) ~= "number" or gemCost ~= gemCost or gemCost == math.huge or gemCost <= 0 then
		return { ok = false, err = ErrorCodes.FUSE_INVALID }
	end

	if not EconomyService.Spend(player, "Gems", gemCost) then
		return { ok = false, err = ErrorCodes.NOT_ENOUGH_GEMS }
	end

	-- Sem yield após Spend: gera o novo UUID e troca os 5 pets pelo Dourado num único Update.
	local newUuid = HttpService:GenerateGUID(false)
	while data.Inventory[newUuid] ~= nil do
		newUuid = HttpService:GenerateGUID(false)
	end

	local updated = DataService.Update(player, "Inventory", function(inventory: { [string]: Types.PetInstance })
		for _, uuid in uuids :: { string } do
			inventory[uuid] = nil
		end
		while inventory[newUuid] ~= nil do
			newUuid = HttpService:GenerateGUID(false)
		end
		inventory[newUuid] = { Id = petId, Variant = "Golden" }
		return inventory
	end)
	if updated == nil then
		EconomyService.AddGems(player, gemCost)
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end

	DataService.Save(player)
	return {
		ok = true,
		data = {
			uuid = newUuid,
			petId = petId,
			variant = "Golden",
		},
	}
end

-- Soma dos multiplicadores dos pets equipados. Dano = BaseDamage + GetDamageBonus.
function PetService.GetDamageBonus(player: Player): number
	local data = DataService.Get(player)
	if data == nil then
		return 0
	end
	return Inventory.bonus(data, PetsConfig :: any, FusionConfig :: any)
end

-- Cria um pet novo no inventário. Devolve (uuid, nil) ou (nil, ErrorCode).
function PetService.AddPet(player: Player, petId: string, variant: string?): (string?, string?)
	if typeof(petId) ~= "string" or #petId < 1 or #petId > 64 then
		return nil, ErrorCodes.INVALID_ARGS
	end
	if PetsConfig[petId] == nil then
		return nil, ErrorCodes.UNKNOWN_ITEM
	end
	if variant ~= nil and not Inventory.isValidVariant(variant) then
		return nil, ErrorCodes.INVALID_ARGS
	end
	local data = DataService.Get(player)
	if data == nil or player.Parent ~= Players then
		return nil, ErrorCodes.DATA_NOT_LOADED
	end
	local canAdd, addErr = Inventory.canAdd(data, GameConfig.MaxInventory)
	if not canAdd then
		return nil, addErr or ErrorCodes.INVENTORY_FULL
	end

	local uuid = HttpService:GenerateGUID(false)
	while data.Inventory[uuid] ~= nil do
		uuid = HttpService:GenerateGUID(false)
	end

	local updated = DataService.Update(player, "Inventory", function(inventory: { [string]: Types.PetInstance })
		inventory[uuid] = if variant ~= nil then { Id = petId, Variant = variant } else { Id = petId }
		return inventory
	end)
	if updated == nil then
		return nil, ErrorCodes.DATA_NOT_LOADED
	end
	return uuid, nil
end

function PetService.Init()
	NetServer.OnInvoke("EquipPet", equipPet, { rate = PET_REMOTE_RATE, burst = PET_REMOTE_BURST })
	NetServer.OnInvoke("UnequipPet", unequipPet, { rate = PET_REMOTE_RATE, burst = PET_REMOTE_BURST })
	NetServer.OnInvoke("FusePets", fusePets, { rate = FUSE_REMOTE_RATE, burst = FUSE_REMOTE_BURST })
	DataService.Loaded:Connect(onProfileLoaded)
	DataService.Changed:Connect(onDataChanged)
	Players.PlayerRemoving:Connect(function(player)
		initializedPlayers[player] = nil
	end)
end

function PetService.Start()
	for _, player in Players:GetPlayers() do
		if not initializedPlayers[player] and DataService.IsLoaded(player) then
			local data = DataService.Get(player)
			if data ~= nil then
				onProfileLoaded(player, data)
			end
		end
	end
end

return PetService
