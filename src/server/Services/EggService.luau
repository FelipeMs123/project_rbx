--!strict
-- EggService.luau (ServerScriptService.Server.Services.EggService)
-- Dono: Squad B. Compra de ovos e sorteio do pet (remote PurchaseEgg).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local EggsConfig = require(Shared.Config.Eggs)
local GameConfig = require(Shared.Config.Game)
local ErrorCodes = require(Shared.ErrorCodes)
local Inventory = require(Shared.Logic.Inventory)
local WeightedRoll = require(Shared.Logic.WeightedRoll)
local Types = require(Shared.Types)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PetService = require(script.Parent.PetService)

local PURCHASE_EGG_RATE = 4
local PURCHASE_EGG_BURST = 6
local MAX_EGG_DISTANCE = 24

local rng = Random.new()

local EggService = {}

local function findEggInstance(areaId: string, eggId: string): Instance?
	local areasFolder = Workspace:FindFirstChild("Areas")
	local areaFolder = areasFolder and areasFolder:FindFirstChild(areaId)
	local eggsFolder = areaFolder and areaFolder:FindFirstChild("Eggs")
	return eggsFolder and eggsFolder:FindFirstChild(eggId)
end

local function getEggPosition(eggInstance: Instance): Vector3?
	if eggInstance:IsA("Model") then
		if eggInstance.PrimaryPart then
			return eggInstance.PrimaryPart.Position
		end
		return eggInstance:GetPivot().Position
	elseif eggInstance:IsA("BasePart") then
		return eggInstance.Position
	end
	return nil
end

local function handlePurchaseEgg(player: Player, eggId: any): Types.Result
	if typeof(eggId) ~= "string" or #eggId < 1 or #eggId > 64 then
		return { ok = false, err = ErrorCodes.INVALID_ARGS }
	end
	local eggDef = EggsConfig[eggId]
	if eggDef == nil then
		return { ok = false, err = ErrorCodes.UNKNOWN_ITEM }
	end

	if player.Parent ~= Players or not DataService.IsLoaded(player) then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end
	local data = DataService.Get(player)
	if data == nil then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end

	if not EconomyService.HasArea(player, eggDef.Area) then
		return { ok = false, err = ErrorCodes.AREA_LOCKED }
	end

	local eggInstance = findEggInstance(eggDef.Area, eggId)
	if eggInstance ~= nil then
		local eggPosition = getEggPosition(eggInstance)
		if eggPosition ~= nil then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
				return { ok = false, err = ErrorCodes.TOO_FAR }
			end
			if not ((root.Position - eggPosition).Magnitude <= MAX_EGG_DISTANCE) then
				return { ok = false, err = ErrorCodes.TOO_FAR }
			end
		end
	end

	local canAdd, addErr = Inventory.canAdd(data, GameConfig.MaxInventory)
	if not canAdd then
		return { ok = false, err = addErr or ErrorCodes.INVENTORY_FULL }
	end

	local insufficientErr = if eggDef.Currency == "Gems"
		then ErrorCodes.NOT_ENOUGH_GEMS
		else ErrorCodes.NOT_ENOUGH_COINS
	if eggDef.Price > 0 and not EconomyService.Spend(player, eggDef.Currency, eggDef.Price) then
		return { ok = false, err = insufficientErr }
	end

	local petId = WeightedRoll.pick(eggDef.Weights, rng:NextNumber())
	local uuid, petErr = PetService.AddPet(player, petId)
	if uuid == nil then
		if eggDef.Price > 0 then
			if eggDef.Currency == "Gems" then
				EconomyService.AddGems(player, eggDef.Price)
			elseif type(data.Rebirths) == "number" and data.Rebirths <= 0 then
				EconomyService.AddCoins(player, eggDef.Price)
			else
				DataService.Update(player, "Coins", function(coins: number)
					return coins + eggDef.Price
				end)
			end
		end
		return { ok = false, err = petErr or ErrorCodes.INTERNAL }
	end

	DataService.Save(player)
	return { ok = true, data = { uuid = uuid, petId = petId } }
end

function EggService.Init()
	NetServer.OnInvoke("PurchaseEgg", handlePurchaseEgg, {
		rate = PURCHASE_EGG_RATE,
		burst = PURCHASE_EGG_BURST,
	})
end

function EggService.Start() end

return EggService
