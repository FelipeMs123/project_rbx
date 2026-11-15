--!strict
-- EggController.luau (StarterPlayerScripts.Client.Controllers.EggController)
-- Dono: Squad B. Controlador de ovos no cliente: placeholders, proximidade, compra segura e animação.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AreasConfig = require(Shared.Config.Areas)
local EggsConfig = require(Shared.Config.Eggs)
local ErrorCodes = require(Shared.ErrorCodes)
local GameConfig = require(Shared.Config.Game)
local PetsConfig = require(Shared.Config.Pets)
local RequestGuard = require(Shared.Logic.RequestGuard)
local NetClient = require(script.Parent.Parent.Net.NetClient)
local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)
local EggHelpers = require(script.Parent.Parent.UI.Eggs.EggHelpers)
local EggUI = require(script.Parent.Parent.UI.Eggs.EggUI)

local EGG_INTERACT_RANGE = 14
local PROXIMITY_CHECK_INTERVAL = 0.1 -- ~10 Hz
local PURCHASE_TIMEOUT_SECONDS = 8
local TIMEOUT_WAIT_MESSAGE = "O servidor demorou para responder. Você já pode tentar novamente."
local PLACEHOLDER_FOLDER_NAME = "ClientPlaceholderEggs"

-- Coordenadas canônicas da B3/B6 para fallback do placeholder dentro dos 24 studs do servidor.
local CANONICAL_EGG_POSITIONS: { [string]: Vector3 } = {
	CandyEgg = Vector3.new(0, 5, -28),
	ChocolateEgg = Vector3.new(140, 5, -28),
}

type TrackedEgg = {
	EggId: string,
	Instance: Instance,
	IsPlaceholder: boolean,
	Hooks: { RBXScriptConnection },
}

local EggController = {}

local localPlayer = Players.LocalPlayer
local isStarted = false
local activeEggId: string? = nil
local proximityAccumulator = 0

local function scheduleTimeoutThread(seconds: number, callback: () -> ()): any
	return task.delay(seconds, callback)
end

local function cancelTimeoutThread(handle: any)
	if typeof(handle) == "thread" and handle ~= coroutine.running() then
		pcall(task.cancel, handle)
	end
end

local function generateRequestId(): string
	return HttpService:GenerateGUID(false)
end

local purchaseGuard = RequestGuard.new(cancelTimeoutThread, generateRequestId)

local trackedEggs: { [string]: TrackedEgg } = {}
local areaWatchConnections: { RBXScriptConnection } = {}
local mainConnections: { RBXScriptConnection } = {}
local placeholderFolder: Folder? = nil

local function getAreaDisplayName(areaId: string): string
	local areaDef = (AreasConfig :: any)[areaId]
	if areaDef and type(areaDef.Name) == "string" then
		return areaDef.Name
	end
	return areaId
end

local function isGuiModalVisible(playerGui: Instance, guiName: string, modalName: string): boolean
	local screenGui = playerGui:FindFirstChild(guiName)
	if not screenGui then
		return false
	end
	if screenGui:IsA("ScreenGui") and not screenGui.Enabled then
		return false
	end
	local modal = screenGui:FindFirstChild(modalName) or screenGui:FindFirstChild(modalName, true)
	return modal ~= nil and modal:IsA("GuiObject") and modal.Visible
end

local function isAnyModalOpen(): boolean
	if EggUI.IsHatchOverlayVisible() then
		return true
	end
	if not localPlayer then
		return false
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui") or localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return false
	end
	return isGuiModalVisible(playerGui, "EggHatchGui", "EggHatchOverlay")
		or isGuiModalVisible(playerGui, "RebirthGui", "RebirthModal")
		or isGuiModalVisible(playerGui, "PetInventoryGui", "PetsModal")
end

local function getInstancePosition(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		if inst.PrimaryPart then
			return inst.PrimaryPart.Position
		end
		return inst:GetPivot().Position
	end
	return nil
end

local function getPlayerRootPosition(): Vector3?
	if not localPlayer then
		return nil
	end
	local character = localPlayer.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local primary = character.PrimaryPart
	if primary then
		return primary.Position
	end
	return nil
end

local function refreshActivePrompt()
	if not activeEggId then
		return
	end
	if isAnyModalOpen() then
		activeEggId = nil
		EggUI.HidePrompt()
		return
	end
	local eggDef = (EggsConfig :: any)[activeEggId]
	if not eggDef then
		EggUI.HidePrompt()
		activeEggId = nil
		return
	end
	local snapshot = DataController.Get() :: EggHelpers.PlayerDataLike?
	local areaName = getAreaDisplayName(eggDef.Area)
	EggUI.UpdatePrompt(activeEggId, eggDef, snapshot, areaName, purchaseGuard:IsBusy())
end

local function focusEggPrompt(eggId: string)
	if not isStarted or isAnyModalOpen() then
		return
	end

	local eggDef = (EggsConfig :: any)[eggId] :: EggHelpers.EggDefLike?
	if not eggDef then
		return
	end

	local tracked = trackedEggs[eggId]
	local rootPos = getPlayerRootPosition()
	local eggPos = if tracked then getInstancePosition(tracked.Instance) else nil
	if not rootPos or not eggPos or (rootPos - eggPos).Magnitude > EGG_INTERACT_RANGE then
		HudController.Toast(EggHelpers.translateError("TOO_FAR"), "error")
		return
	end

	activeEggId = eggId
	local snapshot = DataController.Get() :: EggHelpers.PlayerDataLike?
	EggUI.ShowPrompt(eggId, eggDef, snapshot, getAreaDisplayName(eggDef.Area), purchaseGuard:IsBusy())
end

local function requestPurchase(eggId: string)
	if not EggHelpers.canTriggerPurchase(isStarted, purchaseGuard:IsBusy(), isAnyModalOpen()) then
		return
	end

	local eggDef = (EggsConfig :: any)[eggId] :: EggHelpers.EggDefLike?
	if not eggDef then
		HudController.Toast(EggHelpers.translateError("UNKNOWN_ITEM"), "error")
		return
	end

	local tracked = trackedEggs[eggId]
	local rootPos = getPlayerRootPosition()
	local eggPos = if tracked then getInstancePosition(tracked.Instance) else nil
	if not rootPos or not eggPos or (rootPos - eggPos).Magnitude > EGG_INTERACT_RANGE then
		HudController.Toast(EggHelpers.translateError("TOO_FAR"), "error")
		return
	end

	if not purchaseGuard:HasPending(eggId) then
		local snapshot = DataController.Get() :: EggHelpers.PlayerDataLike?
		local canBuy, preErr = EggHelpers.canPurchaseEgg(snapshot, eggDef, GameConfig.MaxInventory, eggId)
		if not canBuy then
			HudController.Toast(EggHelpers.translateError(preErr), "error")
			return
		end
	end

	local token, requestId = purchaseGuard:Begin(eggId)
	if not token or not requestId then
		return
	end
	refreshActivePrompt()

	purchaseGuard:ScheduleTimeout(token, PURCHASE_TIMEOUT_SECONDS, scheduleTimeoutThread, function()
		refreshActivePrompt()
		HudController.Toast(TIMEOUT_WAIT_MESSAGE, "error")
	end)

	task.spawn(function()
		local result = NetClient.Invoke("PurchaseEgg", eggId, requestId)
		if not result.ok and result.err == ErrorCodes.RATE_LIMITED then
			if purchaseGuard:ResolveTransient(token, requestId) then
				refreshActivePrompt()
				HudController.Toast(EggHelpers.translateError(result.err), "error")
			end
			return
		end

		local accepted = purchaseGuard:ResolveDefinitive(token, requestId)
		if not accepted then
			return
		end

		refreshActivePrompt()

		if result.ok then
			local payload = result.data
			local petId = if type(payload) == "table" then payload.petId else nil
			if type(petId) == "string" then
				local petDef = (PetsConfig :: any)[petId] :: EggHelpers.PetDefLike?
				EggUI.ShowHatchResult(petId, petDef)
				refreshActivePrompt()
			else
				HudController.Toast("Ovo chocado com sucesso!", "reward")
			end
		else
			HudController.Toast(EggHelpers.translateError(result.err), "error")
		end
	end)
end

local function clearTrackedEgg(eggId: string)
	local tracked = trackedEggs[eggId]
	if not tracked then
		return
	end
	for _, conn in tracked.Hooks do
		conn:Disconnect()
	end
	table.clear(tracked.Hooks)
	if tracked.IsPlaceholder and tracked.Instance.Parent then
		tracked.Instance:Destroy()
	end
	trackedEggs[eggId] = nil
end

local function hookInteractiveDescendants(eggId: string, rootInst: Instance, hooks: { RBXScriptConnection })
	local hooked: { [Instance]: boolean } = {}

	local function tryHook(descendant: Instance)
		if hooked[descendant] then
			return
		end
		if descendant:IsA("ProximityPrompt") then
			hooked[descendant] = true
			table.insert(
				hooks,
				descendant.Triggered:Connect(function(triggerPlayer: Player)
					if triggerPlayer == localPlayer then
						focusEggPrompt(eggId)
					end
				end)
			)
		elseif descendant:IsA("ClickDetector") then
			hooked[descendant] = true
			table.insert(
				hooks,
				descendant.MouseClick:Connect(function(clickPlayer: Player)
					if clickPlayer == localPlayer then
						focusEggPrompt(eggId)
					end
				end)
			)
		end
	end

	tryHook(rootInst)
	for _, desc in rootInst:GetDescendants() do
		tryHook(desc)
	end
	table.insert(
		hooks,
		rootInst.DescendantAdded:Connect(function(desc: Instance)
			tryHook(desc)
		end)
	)
end

local function computePlaceholderPosition(eggId: string, eggDef: EggHelpers.EggDefLike): Vector3
	local canonical = CANONICAL_EGG_POSITIONS[eggId]
	if canonical then
		return canonical
	end

	local areasFolder = Workspace:FindFirstChild("Areas")
	local areaInst = if areasFolder then areasFolder:FindFirstChild(eggDef.Area) else nil
	if areaInst then
		local spawns = areaInst:FindFirstChild("BlockSpawns")
		if spawns then
			local firstPart = spawns:FindFirstChildWhichIsA("BasePart")
			if firstPart then
				return firstPart.Position + Vector3.new(10, 2.5, -10)
			end
		end
		local areaPart = areaInst:FindFirstChildWhichIsA("BasePart")
		if areaPart then
			return areaPart.Position + Vector3.new(10, 2.5, -10)
		end
	end

	local areaDef = (AreasConfig :: any)[eggDef.Area]
	local order = if areaDef and type(areaDef.Order) == "number" then areaDef.Order else 1
	local offsetX = 12 + (order - 1) * 16
	return Vector3.new(offsetX, 3.5, -14)
end

local function ensurePlaceholderFolder(): Folder
	if placeholderFolder and placeholderFolder.Parent then
		return placeholderFolder
	end
	local existing = Workspace:FindFirstChild(PLACEHOLDER_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		placeholderFolder = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = PLACEHOLDER_FOLDER_NAME
	folder.Parent = Workspace
	placeholderFolder = folder
	return folder
end

local function createPlaceholderEgg(eggId: string, eggDef: EggHelpers.EggDefLike): Model
	local folder = ensurePlaceholderFolder()
	local model = Instance.new("Model")
	model.Name = eggId

	local body = Instance.new("Part")
	body.Name = "EggBody"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(4.2, 5.4, 4.2)
	body.Anchored = true
	body.CanCollide = false
	body.Material = Enum.Material.SmoothPlastic
	body.Color = if eggId == "ChocolateEgg" then Color3.fromRGB(122, 68, 42) else Color3.fromRGB(255, 148, 210)
	body.Position = computePlaceholderPosition(eggId, eggDef)
	body.Parent = model

	local base = Instance.new("Part")
	base.Name = "Pedestal"
	base.Size = Vector3.new(5.4, 0.8, 5.4)
	base.Anchored = true
	base.CanCollide = true
	base.Material = Enum.Material.SmoothPlastic
	base.Color = Color3.fromRGB(245, 232, 255)
	base.Position = body.Position - Vector3.new(0, 2.9, 0)
	base.Parent = model

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = EGG_INTERACT_RANGE
	click.Parent = body

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EggLabel"
	billboard.Adornee = body
	billboard.Size = UDim2.fromOffset(180, 56)
	billboard.StudsOffset = Vector3.new(0, 4.2, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 45
	billboard.Parent = body

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(30, 23, 51)
	label.BackgroundTransparency = 0.2
	label.Font = Enum.Font.GothamBlack
	label.Text = `{eggDef.Name}\n{EggHelpers.formatPriceText(eggDef)}`
	label.TextColor3 = Color3.fromRGB(255, 232, 138)
	label.TextScaled = true
	label.Parent = billboard

	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 8)
	labelCorner.Parent = label

	model.PrimaryPart = body
	model.Parent = folder
	return model
end

local function findStudioEgg(eggId: string, areaId: string): Instance?
	local areasFolder = Workspace:FindFirstChild("Areas")
	if not areasFolder then
		return nil
	end
	local areaFolder = areasFolder:FindFirstChild(areaId)
	if not areaFolder then
		return nil
	end
	local eggsFolder = areaFolder:FindFirstChild("Eggs")
	if eggsFolder then
		local eggInst = eggsFolder:FindFirstChild(eggId)
		if eggInst and (eggInst:IsA("Model") or eggInst:IsA("BasePart")) then
			return eggInst
		end
	end
	local directEgg = areaFolder:FindFirstChild(eggId)
	if directEgg and (directEgg:IsA("Model") or directEgg:IsA("BasePart")) then
		return directEgg
	end
	return nil
end

local function syncAllEggs()
	if not isStarted then
		return
	end

	for eggId, eggDefRaw in pairs(EggsConfig :: { [string]: any }) do
		local eggDef = eggDefRaw :: EggHelpers.EggDefLike
		local studioEgg = findStudioEgg(eggId, eggDef.Area)
		local existing = trackedEggs[eggId]

		if studioEgg then
			if not existing or existing.IsPlaceholder or existing.Instance ~= studioEgg then
				clearTrackedEgg(eggId)
				local hooks: { RBXScriptConnection } = {}
				hookInteractiveDescendants(eggId, studioEgg, hooks)
				trackedEggs[eggId] = {
					EggId = eggId,
					Instance = studioEgg,
					IsPlaceholder = false,
					Hooks = hooks,
				}
			end
		else
			if not existing or not existing.IsPlaceholder or not existing.Instance.Parent then
				clearTrackedEgg(eggId)
				local placeholder = createPlaceholderEgg(eggId, eggDef)
				local hooks: { RBXScriptConnection } = {}
				hookInteractiveDescendants(eggId, placeholder, hooks)
				trackedEggs[eggId] = {
					EggId = eggId,
					Instance = placeholder,
					IsPlaceholder = true,
					Hooks = hooks,
				}
			end
		end
	end
end

local function rebindAreaWatchers()
	for _, conn in areaWatchConnections do
		conn:Disconnect()
	end
	table.clear(areaWatchConnections)

	local areasFolder = Workspace:FindFirstChild("Areas")
	if areasFolder then
		table.insert(
			areaWatchConnections,
			areasFolder.ChildAdded:Connect(function()
				rebindAreaWatchers()
				syncAllEggs()
			end)
		)
		table.insert(
			areaWatchConnections,
			areasFolder.ChildRemoved:Connect(function()
				rebindAreaWatchers()
				syncAllEggs()
			end)
		)

		for _, areaChild in areasFolder:GetChildren() do
			table.insert(
				areaWatchConnections,
				areaChild.ChildAdded:Connect(function()
					rebindAreaWatchers()
					syncAllEggs()
				end)
			)
			table.insert(
				areaWatchConnections,
				areaChild.ChildRemoved:Connect(function()
					rebindAreaWatchers()
					syncAllEggs()
				end)
			)

			local eggsFolder = areaChild:FindFirstChild("Eggs")
			if eggsFolder then
				table.insert(
					areaWatchConnections,
					eggsFolder.ChildAdded:Connect(function()
						syncAllEggs()
					end)
				)
				table.insert(
					areaWatchConnections,
					eggsFolder.ChildRemoved:Connect(function()
						syncAllEggs()
					end)
				)
			end
		end
	end
end

local function updateProximity()
	if isAnyModalOpen() then
		if activeEggId or EggUI.IsPromptVisible() then
			activeEggId = nil
			EggUI.HidePrompt()
		end
		return
	end

	local rootPos = getPlayerRootPosition()
	if not rootPos then
		if activeEggId or EggUI.IsPromptVisible() then
			activeEggId = nil
			EggUI.HidePrompt()
		end
		return
	end

	local nearestId: string? = nil
	local nearestDistance = EGG_INTERACT_RANGE

	if activeEggId then
		local currentTracked = trackedEggs[activeEggId]
		local currentPos = if currentTracked then getInstancePosition(currentTracked.Instance) else nil
		if currentPos and (rootPos - currentPos).Magnitude <= EGG_INTERACT_RANGE then
			nearestId = activeEggId
		end
	end

	if not nearestId then
		for eggId, tracked in pairs(trackedEggs) do
			local eggPos = getInstancePosition(tracked.Instance)
			if eggPos then
				local dist = (rootPos - eggPos).Magnitude
				if dist <= nearestDistance then
					nearestDistance = dist
					nearestId = eggId
				end
			end
		end
	end

	if nearestId ~= activeEggId or (nearestId ~= nil and not EggUI.IsPromptVisible()) then
		activeEggId = nearestId
		if nearestId then
			local eggDef = (EggsConfig :: any)[nearestId] :: EggHelpers.EggDefLike?
			if eggDef then
				local snapshot = DataController.Get() :: EggHelpers.PlayerDataLike?
				EggUI.ShowPrompt(nearestId, eggDef, snapshot, getAreaDisplayName(eggDef.Area), purchaseGuard:IsBusy())
			end
		else
			EggUI.HidePrompt()
		end
	end
end

function EggController.Init()
	-- Init sem yield: apenas registra callback da UI.
	EggUI.Init(function(eggId: string)
		requestPurchase(eggId)
	end)
end

function EggController.Start()
	if isStarted then
		return
	end
	isStarted = true
	EggUI.Mount()

	rebindAreaWatchers()
	syncAllEggs()

	table.insert(
		mainConnections,
		Workspace.ChildAdded:Connect(function(child: Instance)
			if child.Name == "Areas" then
				rebindAreaWatchers()
				syncAllEggs()
			end
		end)
	)
	table.insert(
		mainConnections,
		Workspace.ChildRemoved:Connect(function(child: Instance)
			if child.Name == "Areas" then
				rebindAreaWatchers()
				syncAllEggs()
			end
		end)
	)

	local observedKeys = { "Coins", "Gems", "UnlockedAreas", "Inventory" }
	for _, key in observedKeys do
		local conn = DataController.Observe(key, function(_value: any)
			refreshActivePrompt()
		end)
		table.insert(mainConnections, conn :: any)
	end

	table.insert(
		mainConnections,
		RunService.Heartbeat:Connect(function(dt: number)
			proximityAccumulator += dt
			if proximityAccumulator >= PROXIMITY_CHECK_INTERVAL then
				proximityAccumulator = 0
				updateProximity()
			end
		end)
	)
end

function EggController.Destroy()
	isStarted = false
	purchaseGuard:Reset()
	activeEggId = nil

	for _, conn in mainConnections do
		conn:Disconnect()
	end
	table.clear(mainConnections)

	for _, conn in areaWatchConnections do
		conn:Disconnect()
	end
	table.clear(areaWatchConnections)

	for eggId in pairs(trackedEggs) do
		clearTrackedEgg(eggId)
	end

	if placeholderFolder and placeholderFolder.Parent then
		placeholderFolder:Destroy()
	end
	placeholderFolder = nil

	EggUI.Destroy()
end

return EggController
