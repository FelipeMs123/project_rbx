--!strict
-- PetController.luau (StarterPlayerScripts.Client.Controllers.PetController)
-- Dono: Squad B. Faz os pets equipados seguirem todos os jogadores no cliente (sem física)
-- e conecta a tela de inventário de pets aos dados e remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local PetsConfig = require(Shared.Config.Pets)
local Types = require(Shared.Types)

local DataController = require(script.Parent.DataController)
local NetClient = require(script.Parent.Parent.Net.NetClient)
local PetInventoryUI = require(script.Parent.Parent.UI.Pets.PetInventoryUI)

local PetController = {}

type VisualPet = {
	petId: string,
	model: Model,
	currentCFrame: CFrame,
	initialized: boolean,
	phaseOffset: number,
	effectsEnabled: boolean,
}

type PlayerPetState = {
	connections: { RBXScriptConnection },
	pets: { VisualPet },
	culled: boolean,
}

local DEFAULT_RARITY_COLOR = Color3.fromRGB(255, 184, 210)

local RARITY_COLORS: { [string]: Color3 } = {
	Common = DEFAULT_RARITY_COLOR,
	Uncommon = Color3.fromRGB(123, 237, 159),
	Rare = Color3.fromRGB(112, 161, 255),
	Epic = Color3.fromRGB(165, 94, 234),
	Legendary = Color3.fromRGB(255, 211, 42),
}

local FOLLOW_SPEED = 11
local BOB_FREQUENCY = 4.2
local BOB_AMPLITUDE = 0.45
local LATERAL_SPACING = 3.0
local BACK_DISTANCE = 4.2
local REQUEST_TIMEOUT_SECONDS = 8
local TIMEOUT_MESSAGE = "O servidor demorou para responder. Tente novamente!"
local ORIGINAL_ENABLED_ATTR = "OriginalEnabled"

local playerStates: { [Player]: PlayerPetState } = {}
local petsFolder: Folder? = nil
local pendingRequests: { [string]: boolean } = {}
local requestTokens: { [string]: number } = {}
local nextRequestToken = 0

local function getOrCreatePetsFolder(): Folder
	if petsFolder and petsFolder.Parent then
		return petsFolder
	end
	local existing = Workspace:FindFirstChild("ClientPets")
	if existing and existing:IsA("Folder") then
		petsFolder = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "ClientPets"
	folder.Parent = Workspace
	petsFolder = folder
	return folder
end

local function parseEquippedCsv(raw: any): { string }
	if typeof(raw) ~= "string" or raw == "" then
		return {}
	end
	local result: { string } = {}
	for _, token in string.split(raw, ",") do
		local trimmed = string.gsub(token, "^%s*(.-)%s*$", "%1")
		if trimmed ~= "" and PetsConfig[trimmed] ~= nil then
			table.insert(result, trimmed)
			if #result >= GameConfig.MaxEquipped then
				break
			end
		end
	end
	return result
end

local function enforceNoPhysics(model: Model)
	local firstPart: BasePart? = nil
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanQuery = false
			desc.CanTouch = false
			desc.Massless = true
			if not firstPart then
				firstPart = desc
			end
		end
	end
	if not model.PrimaryPart and firstPart then
		model.PrimaryPart = firstPart
	end
end

local function createPlaceholderModel(petId: string, def: Types.PetDef): Model
	local model = Instance.new("Model")
	model.Name = `Pet_{petId}`

	local body = Instance.new("Part")
	body.Name = "PrimaryPart"
	body.Size = Vector3.new(1.8, 1.8, 1.8)
	body.Material = Enum.Material.SmoothPlastic
	body.Color = RARITY_COLORS[def.Rarity] or DEFAULT_RARITY_COLOR
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model

	local cornerMesh = Instance.new("SpecialMesh")
	cornerMesh.MeshType = Enum.MeshType.Sphere
	cornerMesh.Scale = Vector3.new(1, 0.92, 1.05)
	cornerMesh.Parent = body

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.fromOffset(110, 26)
	billboard.StudsOffset = Vector3.new(0, 1.7, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 45
	billboard.Parent = body

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = def.Name
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Parent = billboard

	model.PrimaryPart = body
	return model
end

local function isToggleableEffect(inst: Instance): boolean
	return inst:IsA("ParticleEmitter")
		or inst:IsA("Sparkles")
		or inst:IsA("Trail")
		or inst:IsA("Beam")
		or inst:IsA("BillboardGui")
end

local function captureOriginalEffectStates(model: Model)
	for _, desc in model:GetDescendants() do
		if isToggleableEffect(desc) and desc:GetAttribute(ORIGINAL_ENABLED_ATTR) == nil then
			desc:SetAttribute(ORIGINAL_ENABLED_ATTR, (desc :: any).Enabled == true)
		end
	end
end

local function setEffectsEnabled(model: Model, enabled: boolean)
	for _, desc in model:GetDescendants() do
		if isToggleableEffect(desc) then
			local origAttr = desc:GetAttribute(ORIGINAL_ENABLED_ATTR)
			local originalEnabled = if typeof(origAttr) == "boolean" then origAttr else ((desc :: any).Enabled == true)
			if origAttr == nil then
				desc:SetAttribute(ORIGINAL_ENABLED_ATTR, originalEnabled)
			end
			(desc :: any).Enabled = if enabled then originalEnabled else false
		end
	end
end

local function createPetModel(petId: string): Model?
	local def = PetsConfig[petId]
	if not def then
		return nil
	end

	local petModelsFolder = ReplicatedStorage:FindFirstChild("PetModels")
	if petModelsFolder then
		local template = petModelsFolder:FindFirstChild(petId)
		if template then
			if template:IsA("Model") then
				local clone = template:Clone()
				enforceNoPhysics(clone)
				if clone.PrimaryPart then
					captureOriginalEffectStates(clone)
					return clone
				end
				clone:Destroy()
			elseif template:IsA("BasePart") then
				local wrapper = Instance.new("Model")
				wrapper.Name = `Pet_{petId}`
				local partClone = template:Clone()
				partClone.Parent = wrapper
				wrapper.PrimaryPart = partClone
				enforceNoPhysics(wrapper)
				captureOriginalEffectStates(wrapper)
				return wrapper
			end
		end
	end

	local placeholder = createPlaceholderModel(petId, def)
	captureOriginalEffectStates(placeholder)
	return placeholder
end

local function clearPlayerPets(state: PlayerPetState)
	for _, visual in state.pets do
		visual.model:Destroy()
	end
	table.clear(state.pets)
	state.culled = false
end

local function rebuildPlayerPets(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end

	clearPlayerPets(state)

	local character = player.Character
	if not character then
		return
	end

	local petIds = parseEquippedCsv(player:GetAttribute("EquippedPets"))
	if #petIds == 0 then
		return
	end

	local folder = getOrCreatePetsFolder()
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local hasRoot = rootPart ~= nil and rootPart:IsA("BasePart")
	local baseCFrame = if hasRoot then (rootPart :: BasePart).CFrame else CFrame.new()
	state.culled = not hasRoot

	for index, petId in petIds do
		local model = createPetModel(petId)
		if model then
			model.Name = `{player.Name}_Pet_{index}_{petId}`
			if hasRoot then
				model:PivotTo(baseCFrame)
				model.Parent = folder
			else
				setEffectsEnabled(model, false)
			end
			table.insert(state.pets, {
				petId = petId,
				model = model,
				currentCFrame = baseCFrame,
				initialized = false,
				phaseOffset = (index - 1) * 1.35,
				effectsEnabled = hasRoot,
			})
		end
	end
end

local function cleanupPlayer(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end
	clearPlayerPets(state)
	for _, conn in state.connections do
		conn:Disconnect()
	end
	table.clear(state.connections)
	playerStates[player] = nil
end

local function setupPlayer(player: Player)
	if playerStates[player] then
		return
	end

	local state: PlayerPetState = {
		connections = {},
		pets = {},
		culled = false,
	}
	playerStates[player] = state

	table.insert(
		state.connections,
		player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
			rebuildPlayerPets(player)
		end)
	)

	table.insert(
		state.connections,
		player.CharacterAdded:Connect(function()
			rebuildPlayerPets(player)
		end)
	)

	table.insert(
		state.connections,
		player.CharacterRemoving:Connect(function()
			clearPlayerPets(state)
		end)
	)

	if player.Character then
		rebuildPlayerPets(player)
	end
end

local function computeSlotOffset(index: number, count: number, clockTime: number, phaseOffset: number): CFrame
	local centerOffset = index - (count + 1) / 2
	local lateral = centerOffset * LATERAL_SPACING
	local depth = BACK_DISTANCE + (if count == 3 and index == 2 then 0.9 else 0)
	local bobY = -0.35 + math.sin(clockTime * BOB_FREQUENCY + phaseOffset) * BOB_AMPLITUDE
	local tiltZ = math.cos(clockTime * (BOB_FREQUENCY * 0.5) + phaseOffset) * math.rad(6)
	return CFrame.new(lateral, bobY, depth) * CFrame.Angles(0, 0, tiltZ)
end

local function stepAllPets(dt: number)
	local camera = Workspace.CurrentCamera
	local cameraPos = if camera then camera.CFrame.Position else Vector3.zero
	local maxRadius = GameConfig.EffectsRadius
	local now = os.clock()
	local alpha = math.clamp(1 - math.exp(-FOLLOW_SPEED * dt), 0, 1)
	local folder = getOrCreatePetsFolder()

	for player, state in playerStates do
		local count = #state.pets
		if count == 0 then
			continue
		end

		local character = player.Character
		local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not rootPart or not rootPart:IsA("BasePart") then
			continue
		end

		local rootCFrame = rootPart.CFrame
		local distanceFromCamera = (rootCFrame.Position - cameraPos).Magnitude

		-- Fora do EffectsRadius: oculta modelos, desliga efeitos e pula atualização por frame
		if distanceFromCamera > maxRadius then
			if not state.culled then
				state.culled = true
				for _, visual in state.pets do
					if visual.effectsEnabled then
						setEffectsEnabled(visual.model, false)
						visual.effectsEnabled = false
					end
					visual.model.Parent = nil
					visual.initialized = false
				end
			end
			continue
		end

		if state.culled then
			state.culled = false
			for _, visual in state.pets do
				visual.model.Parent = folder
				if not visual.effectsEnabled then
					setEffectsEnabled(visual.model, true)
					visual.effectsEnabled = true
				end
			end
		end

		for index, visual in state.pets do
			local slotOffset = computeSlotOffset(index, count, now, visual.phaseOffset)
			local targetCFrame = rootCFrame * slotOffset

			if not visual.initialized or (visual.currentCFrame.Position - targetCFrame.Position).Magnitude > 35 then
				visual.currentCFrame = targetCFrame
				visual.initialized = true
			else
				visual.currentCFrame = visual.currentCFrame:Lerp(targetCFrame, alpha)
			end

			visual.model:PivotTo(visual.currentCFrame)
		end
	end
end

local function tryShowHudToast(message: string, isError: boolean): boolean
	local controllersFolder = script.Parent
	if not controllersFolder then
		return false
	end
	local hudModule = controllersFolder:FindFirstChild("HudController")
	if not hudModule or not hudModule:IsA("ModuleScript") then
		return false
	end
	local okRequire, hudController = pcall(require :: any, hudModule)
	if not okRequire or type(hudController) ~= "table" then
		return false
	end
	local toastFn = (hudController :: { Toast: unknown }).Toast
	if type(toastFn) ~= "function" then
		return false
	end
	local kind = if isError then "error" else "info"
	local okCall = pcall(toastFn :: (string, string) -> (), message, kind)
	return okCall
end

local function showFeedback(message: string, isError: boolean)
	local shownInHud = tryShowHudToast(message, isError)
	if not shownInHud or PetInventoryUI.IsModalOpen() then
		PetInventoryUI.ShowToast(message, isError)
	end
end

local function handleTogglePet(uuid: string, currentlyEquipped: boolean)
	if pendingRequests[uuid] or PetInventoryUI.IsPending(uuid) then
		return
	end

	nextRequestToken += 1
	local token = nextRequestToken
	pendingRequests[uuid] = true
	requestTokens[uuid] = token
	PetInventoryUI.SetPending(uuid, true)

	local remoteName = if currentlyEquipped then "UnequipPet" else "EquipPet"

	task.delay(REQUEST_TIMEOUT_SECONDS, function()
		if requestTokens[uuid] ~= token then
			return
		end
		requestTokens[uuid] = nil
		pendingRequests[uuid] = nil
		PetInventoryUI.SetPending(uuid, false)
		showFeedback(TIMEOUT_MESSAGE, true)
		PetInventoryUI.Refresh(DataController.Get())
	end)

	task.spawn(function()
		local result = NetClient.Invoke(remoteName, uuid)
		if requestTokens[uuid] ~= token then
			return
		end
		requestTokens[uuid] = nil
		pendingRequests[uuid] = nil
		PetInventoryUI.SetPending(uuid, false)

		if not result.ok then
			showFeedback(PetInventoryUI.TranslateError(result.err), true)
		end

		PetInventoryUI.Refresh(DataController.Get())
	end)
end

function PetController.Init()
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)
	RunService.RenderStepped:Connect(stepAllPets)
end

function PetController.Start()
	PetInventoryUI.Mount(handleTogglePet)
	PetInventoryUI.Refresh(DataController.Get())

	DataController.Observe("Inventory", function()
		PetInventoryUI.Refresh(DataController.Get())
	end)

	DataController.Observe("Equipped", function()
		PetInventoryUI.Refresh(DataController.Get())
	end)
end

return PetController
