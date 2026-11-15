--!strict
-- StarterPlayerScripts.Client.Controllers.TutorialController
-- Dono: Squad A. Observa o progresso e pede ao servidor o avanço do tutorial.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config.Tutorial)
local Tutorial = require(ReplicatedStorage.Shared.Logic.Tutorial)
local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)
local NetClient = require(script.Parent.Parent.Net.NetClient)
local UI = require(script.Parent.Parent.UI.Tutorial.TutorialUI)
local Messages = require(script.Parent.Parent.UI.Hud.Messages)

local TutorialController = {}
local total = #Config
local started = false
local current: number? = nil
local inFlight = false
local confirmed: number? = nil
local blockSatisfied: number? = nil
local retryScheduled = false
local petsModal: GuiObject? = nil
local modalConnection: RBXScriptConnection? = nil
local connections: { any } = {} -- mistura RBXScriptConnection e as conexões do DataController.Observe
local symbols: { [string]: string } = {
	BreakFirstBlock = "🍬",
	Reach100Coins = "●",
	BuyCandyEgg = "🥚",
	EquipPet = "★",
	BreakLollipop = "🍭",
}

local function partOf(instance: Instance?): BasePart?
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	local core = instance:FindFirstChild("Core", true)
	if core and core:IsA("BasePart") then
		return core
	end
	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function updateGuide()
	local index = if current then Tutorial.currentIndex(current, total) else nil
	local step = if index then Config[index] else nil
	if not step then
		UI.SetTarget(nil)
		UI.Highlight(nil)
		return
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local pets = if playerGui then playerGui:FindFirstChild("PetInventoryGui") else nil
	local modal = if pets then pets:FindFirstChild("PetsModal", true) else nil
	local nextModal = if modal and modal:IsA("GuiObject") then modal else nil
	if nextModal ~= petsModal then
		if modalConnection then
			modalConnection:Disconnect()
			modalConnection = nil
		end
		petsModal = nextModal
		if nextModal then
			modalConnection = nextModal:GetPropertyChangedSignal("Visible"):Connect(function()
				local hidden = nextModal.Visible
				UI.SetBannerVisible(not hidden)
				HudController.SetTopReserve(if hidden then 0 else UI.Height + 8)
			end)
		end
	end
	local hidden = nextModal ~= nil and nextModal.Visible
	UI.SetBannerVisible(not hidden)
	HudController.SetTopReserve(if hidden then 0 else UI.Height + 8)
	local button = if pets and step.Id == "EquipPet" then pets:FindFirstChild("PetsToggleButton", true) else nil
	UI.Highlight(if button and button:IsA("GuiObject") then button else nil)
	local target: BasePart? = nil
	if step.Id == "BuyCandyEgg" then
		local areas = Workspace:FindFirstChild("Areas")
		local plaza = if areas then areas:FindFirstChild("CandyPlaza") else nil
		local eggs = if plaza then plaza:FindFirstChild("Eggs") else nil
		target = partOf(if eggs then eggs:FindFirstChild("CandyEgg") else nil)
	elseif step.Id == "BreakFirstBlock" or step.Id == "BreakLollipop" then
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local blocks = Workspace:FindFirstChild("Blocks")
		local distance = math.huge
		if root and root:IsA("BasePart") and blocks then
			for _, model in blocks:GetChildren() do
				local hp = model:GetAttribute("HP")
				local wanted = if step.Id == "BreakFirstBlock" then "GummyBlock" else step.BlockId
				if
					model:IsA("Model")
					and model:GetAttribute("BlockType") == wanted
					and typeof(hp) == "number"
					and hp > 0
				then
					local part = partOf(model)
					if part then
						local nextDistance = (root.Position - part.Position).Magnitude
						if nextDistance < distance then
							distance = nextDistance
							target = part
						end
					end
				end
			end
		end
	end
	UI.SetTarget(target)
end

local refresh: () -> ()

local function advance(step: number)
	if inFlight or retryScheduled or confirmed == step then
		return
	end
	inFlight = true
	task.spawn(function()
		local result = NetClient.Invoke("SetTutorialStep", step + 1)
		inFlight = false
		if result.ok then
			-- Não altera a cópia local: espera TutorialStep por DataChanged.
			if current == step then
				confirmed = step
			else
				refresh()
			end
		elseif current == step then
			if result.err ~= "RATE_LIMITED" then
				HudController.Toast(Messages.message(result.err), "error")
			end
			if not retryScheduled then
				retryScheduled = true
				task.delay(1.5, function()
					retryScheduled = false
					if current == step then
						advance(step)
					else
						refresh()
					end
				end)
			end
		end
	end)
end

refresh = function()
	local data = DataController.Get()
	if not data then
		return
	end
	local previous = current
	current = data.TutorialStep
	local stepNumber = data.TutorialStep
	if previous ~= stepNumber then
		confirmed = nil
		blockSatisfied = nil
	end
	if Tutorial.isDone(stepNumber, total) then
		UI.Hide()
		if modalConnection then
			modalConnection:Disconnect()
			modalConnection = nil
		end
		HudController.SetTopReserve(0)
		if previous and not Tutorial.isDone(previous, total) and previous == total - 1 then
			HudController.Toast("Muito bem! Agora é com você! 🎉", "reward")
		end
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		return
	end
	local index = Tutorial.currentIndex(stepNumber, total)
	if not index then
		return
	end
	local step = Config[index]
	local inventoryCount = 0
	for _ in data.Inventory do
		inventoryCount += 1
	end
	local snapshot = { Coins = data.Coins, InventoryCount = inventoryCount, EquippedCount = #data.Equipped }
	local value, target = Tutorial.progress(step, snapshot)
	local suffix = if step.Id == "Reach100Coins"
		then "moedas"
		elseif step.Id == "BuyCandyEgg" then "pet"
		elseif step.Id == "EquipPet" then "equipado"
		else nil
	UI.Show(step.Text, symbols[step.Id] or "★", value, target, suffix)
	HudController.SetTopReserve(UI.Height + 8)
	updateGuide()
	if blockSatisfied == stepNumber or Tutorial.isStepSatisfied(step, snapshot) then
		advance(stepNumber)
	end
end

function TutorialController.Init()
	-- NetClient.On pode esperar replicação; o registro fica em Start.
end

function TutorialController.Start()
	if started then
		return
	end
	started = true
	UI.Mount(Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui)
	for _, key in { "TutorialStep", "Coins", "Inventory", "Equipped" } do
		table.insert(connections, DataController.Observe(key, refresh))
	end
	table.insert(
		connections,
		NetClient.On("Notify", function(code: any, payload: any)
			if code ~= "REWARD" or current == nil then
				return
			end
			local index = Tutorial.currentIndex(current, total)
			local step = if index then Config[index] else nil
			if step and Tutorial.rewardCompletesStep(step, payload) then
				blockSatisfied = current
				refresh()
			end
		end)
	)
	refresh()
	task.spawn(function()
		while current == nil or not Tutorial.isDone(current, total) do
			task.wait(0.5)
			updateGuide()
		end
	end)
end

return TutorialController
