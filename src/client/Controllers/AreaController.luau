--!strict
-- StarterPlayerScripts.Client.Controllers.AreaController | Dono: Squad A. Portões locais e pedido de liberação.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)
local NetClient = require(script.Parent.Parent.Net.NetClient)
local Messages = require(script.Parent.Parent.UI.Hud.Messages)

local AreaController = {}
type Original = { transparency: number, canCollide: boolean, canQuery: boolean }
type GateState = {
	gate: Instance,
	areaId: string,
	parts: { [BasePart]: Original },
	connections: { RBXScriptConnection },
	billboard: BillboardGui,
	prompt: ProximityPrompt,
	attachment: Attachment?,
	busy: boolean,
}
local gates: { [Instance]: GateState } = {}
local watched: { [Instance]: { RBXScriptConnection } } = {}
local unlocked: { [string]: boolean } = {}

local function refresh(state: GateState)
	local open = unlocked[state.areaId] == true
	local anchor: BasePart? = if state.gate:IsA("Model") then state.gate.PrimaryPart else nil
	for part, original in state.parts do
		part.Transparency = if open then 1 else original.transparency
		part.CanCollide = if open then false else original.canCollide
		part.CanQuery = if open then false else original.canQuery
	end
	if not anchor or not state.parts[anchor] then
		anchor = nil
		for _, item in state.gate:GetDescendants() do
			if
				item:IsA("BasePart")
				and state.parts[item]
				and (
					not anchor
					or item.Position.Y < anchor.Position.Y
					or (item.Position.Y == anchor.Position.Y and item:GetFullName() < anchor:GetFullName())
				)
			then
				anchor = item
			end
		end
		if state.gate:IsA("BasePart") and state.parts[state.gate] then
			anchor = state.gate
		end
	end
	if state.attachment and state.attachment.Parent ~= anchor then
		state.prompt.Parent = nil
		state.attachment:Destroy()
		state.attachment = nil
	end
	if anchor and not state.attachment then
		local attachment = Instance.new("Attachment")
		attachment.Name = "CandyGateInteraction"
		state.attachment = attachment
		attachment.Parent = anchor :: BasePart
		state.prompt.Parent = attachment
	end
	if anchor then
		state.billboard.Adornee = anchor
	end
	state.billboard.Enabled = not open and anchor ~= nil
	state.prompt.Enabled = not open and anchor ~= nil and not state.busy
end

local function removeGate(gate: Instance)
	local state = gates[gate]
	if not state then
		return
	end
	gates[gate] = nil
	for _, connection in state.connections do
		connection:Disconnect()
	end
	for part, original in state.parts do
		part.Transparency = original.transparency
		part.CanCollide = original.canCollide
		part.CanQuery = original.canQuery
	end
	state.prompt:Destroy()
	if state.attachment then
		state.attachment:Destroy()
	end
	state.billboard:Destroy()
end

local function addGate(gate: Instance, areaId: string)
	if gates[gate] or gate.Name ~= "Gate" or not (gate:IsA("Model") or gate:IsA("BasePart")) then
		return
	end
	local definition = Areas[areaId]
	if not definition then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CandyGatePrice"
	billboard.Size = UDim2.fromScale(6, 2)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	billboard.MaxDistance = 65
	billboard.AlwaysOnTop = true
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(50, 30, 65)
	text.BackgroundTransparency = 0.15
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 19
	text.TextWrapped = true
	text.Text = definition.Name .. "\n" .. Format.abbreviate(definition.Price) .. " moedas"
	text.Parent = billboard
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Liberar"
	prompt.ObjectText = definition.Name
	prompt.ClickablePrompt = true
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	local state: GateState = {
		gate = gate,
		areaId = areaId,
		parts = {},
		connections = {},
		billboard = billboard,
		prompt = prompt,
		attachment = nil,
		busy = false,
	}
	gates[gate] = state
	local function addPart(item: Instance)
		if item:IsA("BasePart") and not state.parts[item] then
			state.parts[item] =
				{ transparency = item.Transparency, canCollide = item.CanCollide, canQuery = item.CanQuery }
		end
	end
	addPart(gate)
	for _, item in gate:GetDescendants() do
		addPart(item)
	end
	table.insert(
		state.connections,
		gate.DescendantAdded:Connect(function(item)
			addPart(item)
			refresh(state)
		end)
	)
	table.insert(
		state.connections,
		gate.DescendantRemoving:Connect(function(item)
			if item:IsA("BasePart") then
				local original = state.parts[item]
				if original then
					state.parts[item] = nil
					if state.attachment and state.attachment.Parent == item then
						state.prompt.Parent = nil
						state.attachment:Destroy()
						state.attachment = nil
					end
					item.Transparency = original.transparency
					item.CanCollide = original.canCollide
					item.CanQuery = original.canQuery
					task.defer(function()
						if gates[gate] == state then
							refresh(state)
						end
					end)
				end
			end
		end)
	)
	table.insert(
		state.connections,
		prompt.Triggered:Connect(function()
			if state.busy or unlocked[areaId] then
				return
			end
			state.busy = true
			refresh(state)
			local result = NetClient.Invoke("UnlockArea", areaId)
			if gates[gate] ~= state then
				return
			end
			state.busy = false
			refresh(state)
			if result.ok then
				HudController.Toast("Área liberada!", "reward")
			else
				HudController.Toast(Messages.message(result.err), "error")
			end
		end)
	)
	-- Instâncias criadas pelo cliente não são replicadas aos outros jogadores.
	billboard.Parent = gate
	refresh(state)
end

local function unwatch(instance: Instance)
	local connections = watched[instance]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		watched[instance] = nil
	end
	for gate in gates do
		if gate == instance or gate:IsDescendantOf(instance) then
			removeGate(gate)
		end
	end
end

local function watchArea(area: Instance)
	if watched[area] or not Areas[area.Name] then
		return
	end
	watched[area] = {
		area.ChildAdded:Connect(function(child)
			addGate(child, area.Name)
		end),
		area.ChildRemoved:Connect(removeGate),
	}
	for _, child in area:GetChildren() do
		addGate(child, area.Name)
	end
end

local function watchFolder(folder: Instance)
	if folder.Name ~= "Areas" or watched[folder] then
		return
	end
	watched[folder] = {
		folder.ChildAdded:Connect(watchArea),
		folder.ChildRemoved:Connect(unwatch),
	}
	for _, area in folder:GetChildren() do
		watchArea(area)
	end
end

function AreaController.Init()
	DataController.Observe("UnlockedAreas", function(value: any)
		table.clear(unlocked)
		if type(value) == "table" then
			for _, areaId in value do
				if type(areaId) == "string" then
					unlocked[areaId] = true
				end
			end
		end
		for _, state in gates do
			refresh(state)
		end
	end)
end

function AreaController.Start()
	Workspace.ChildAdded:Connect(watchFolder)
	Workspace.ChildRemoved:Connect(function(folder)
		if folder.Name == "Areas" then
			for _, area in folder:GetChildren() do
				unwatch(area)
			end
			unwatch(folder)
		end
	end)
	for _, folder in Workspace:GetChildren() do
		watchFolder(folder)
	end
end

return AreaController
