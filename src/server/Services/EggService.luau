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
local RequestIdempotency = require(Shared.Logic.RequestIdempotency)
local WeightedRoll = require(Shared.Logic.WeightedRoll)
local Types = require(Shared.Types)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PetService = require(script.Parent.PetService)

local PURCHASE_EGG_RATE = 4
local PURCHASE_EGG_BURST = 6
local MAX_EGG_DISTANCE = 24
local MAX_CACHED_RESULTS = 100

-- Posições canônicas dos pedestais para fallback server-side enquanto o modelo real não existir em Workspace.Areas.
local FALLBACK_EGG_POSITIONS: { [string]: Vector3 } = {
	CandyEgg = Vector3.new(0, 2.6, -28),
	ChocolateEgg = Vector3.new(140, 2.6, -28),
}

local rng = Random.new()
local purchaseIdempotency = RequestIdempotency.new(MAX_CACHED_RESULTS)
local playerRemovingConnected = false

local EggService = {}

local function getEggPosition(eggInstance: Instance): Vector3?
	if eggInstance:IsA("BasePart") then
		return eggInstance.Position
	elseif eggInstance:IsA("Model") then
		local primary = eggInstance.PrimaryPart
		if primary ~= nil and primary:IsA("BasePart") then
			return primary.Position
		end
		local core = eggInstance:FindFirstChild("Core")
		if core ~= nil and core:IsA("BasePart") then
			return core.Position
		end
		local basePart = eggInstance:FindFirstChildWhichIsA("BasePart", true)
		if basePart == nil or not basePart:IsA("BasePart") then
			return nil
		end
		local getBoundingBox = (eggInstance :: any).GetBoundingBox
		if type(getBoundingBox) == "function" then
			local ok, bboxCFrame = pcall(getBoundingBox, eggInstance)
			if ok and bboxCFrame ~= nil and bboxCFrame.Position ~= nil then
				return bboxCFrame.Position
			end
		end
		return basePart.Position
	end
	return nil
end

local function resolveEggPosition(areasFolder: Instance, areaId: string, eggId: string): Vector3?
	local areaFolder = areasFolder:FindFirstChild(areaId)
	local eggsFolder = areaFolder and areaFolder:FindFirstChild("Eggs")
	local eggInstance = eggsFolder and eggsFolder:FindFirstChild(eggId)
	if eggInstance ~= nil then
		-- Se a instância já existe no mapa, nunca faz fallback: instância inválida falha fechada.
		return getEggPosition(eggInstance)
	end
	return FALLBACK_EGG_POSITIONS[eggId]
end

local function executePurchaseEgg(player: Player, eggId: any): Types.Result
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

	-- Exceção headless apenas quando Workspace.Areas não existe; com mapa presente, a validação é fail-closed.
	local areasFolder = Workspace:FindFirstChild("Areas")
	if areasFolder ~= nil then
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local rootPart: Instance? = if character
			then (character:FindFirstChild("HumanoidRootPart") :: Instance? or character.PrimaryPart)
			else nil
		if not humanoid or not (humanoid.Health > 0) or not rootPart or not rootPart:IsA("BasePart") then
			return { ok = false, err = ErrorCodes.TOO_FAR }
		end

		local eggPosition = resolveEggPosition(areasFolder, eggDef.Area, eggId)
		if eggPosition == nil or not ((rootPart.Position - eggPosition).Magnitude <= MAX_EGG_DISTANCE) then
			return { ok = false, err = ErrorCodes.TOO_FAR }
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

local function handlePurchaseEgg(player: Player, eggId: any, requestId: any): Types.Result
	return purchaseIdempotency:Execute(player, requestId, function()
		return executePurchaseEgg(player, eggId)
	end) :: Types.Result
end

function EggService.Init()
	NetServer.OnInvoke("PurchaseEgg", handlePurchaseEgg, {
		rate = PURCHASE_EGG_RATE,
		burst = PURCHASE_EGG_BURST,
	})
	if not playerRemovingConnected then
		playerRemovingConnected = true
		Players.PlayerRemoving:Connect(function(player)
			purchaseIdempotency:Remove(player)
		end)
	end
end

function EggService.Start() end

return EggService
