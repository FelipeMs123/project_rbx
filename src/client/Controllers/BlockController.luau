--!strict
-- StarterPlayerScripts.Client.Controllers.BlockController
-- Dono: Squad A. Entrada, barras de HP e efeitos locais dos blocos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Blocks = require(ReplicatedStorage.Shared.Config.Blocks)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local NetClient = require(script.Parent.Parent.Net.NetClient)
local BlockController = {}

type View = {
	model: Model,
	gui: BillboardGui,
	label: TextLabel,
	fill: Frame,
	connections: { RBXScriptConnection },
	tween: Tween?,
	shake: Tween?,
	offset: CFrameValue?,
	origin: CFrame?,
}

local views: { [Model]: View } = {}
local folder: Instance? = nil
local heldInput: InputObject? = nil
local heldModel: Model? = nil
local lastClick = -math.huge
local initialized = false
local started = false

local function visible(position: Vector3): boolean
	local camera = Workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - position).Magnitude > 60 then
		return false
	end
	local _, onScreen = camera:WorldToViewportPoint(position)
	return onScreen
end

local function effectPart(position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "BlockEffect"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	part.Parent = Workspace
	Debris:AddItem(part, 2)
	return part
end

local function particles(part: BasePart, count: number)
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.35, 0.8)
	emitter.Speed = NumberRange.new(4, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -12, 0)
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 110, 190), Color3.fromRGB(255, 225, 100))
	emitter.Size = NumberSequence.new(0.25)
	emitter.Parent = attachment
	emitter:Emit(count)
end

local function remove(model: Model)
	local view = views[model]
	if not view then
		return
	end
	views[model] = nil
	if heldModel == model then
		heldModel = nil
	end
	for _, connection in view.connections do
		connection:Disconnect()
	end
	if view.tween then
		view.tween:Cancel()
	end
	if view.shake then
		view.shake:Cancel()
	end
	if view.origin then
		model:PivotTo(view.origin)
	end
	if view.offset then
		view.offset:Destroy()
	end
	view.gui:Destroy()
end

local function add(instance: Instance)
	if not instance:IsA("Model") or views[instance] then
		return
	end
	local model = instance
	local gui = Instance.new("BillboardGui")
	gui.Name = "BlockHealth"
	gui.Size = UDim2.fromScale(5, 1.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.6)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Parent = gui
	local background = Instance.new("Frame")
	background.Position = UDim2.fromScale(0, 0.65)
	background.Size = UDim2.fromScale(1, 0.3)
	background.BackgroundColor3 = Color3.fromRGB(50, 30, 60)
	background.BorderSizePixel = 0
	background.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
	fill.BorderSizePixel = 0
	fill.Parent = background
	local view: View = { model = model, gui = gui, label = label, fill = fill, connections = {} }
	views[model] = view
	local function update()
		local primaryPart = model.PrimaryPart
		gui.Enabled = primaryPart ~= nil
		if primaryPart then
			gui.Adornee = primaryPart
		end
		local blockType = model:GetAttribute("BlockType")
		local definition = if typeof(blockType) == "string" then Blocks[blockType] else nil
		local hp = model:GetAttribute("HP")
		local maxHp = model:GetAttribute("MaxHP")
		local ratio = 0
		if typeof(hp) == "number" and typeof(maxHp) == "number" and maxHp > 0 then
			ratio = math.clamp(hp / maxHp, 0, 1)
		end
		label.Text = if definition then definition.Name else "Bloco de doce"
		if view.tween then
			view.tween:Cancel()
		end
		local tween = TweenService:Create(fill, TweenInfo.new(0.12), { Size = UDim2.fromScale(ratio, 1) })
		view.tween = tween
		tween:Play()
	end
	for _, attribute in { "HP", "MaxHP", "BlockType" } do
		table.insert(view.connections, model:GetAttributeChangedSignal(attribute):Connect(update))
	end
	table.insert(view.connections, model:GetPropertyChangedSignal("PrimaryPart"):Connect(update))
	table.insert(
		view.connections,
		model.AncestryChanged:Connect(function()
			if model.Parent ~= folder then
				remove(model)
			end
		end)
	)
	gui.Parent = model
	update()
end

local function target(position: Vector2): Model?
	local camera = Workspace.CurrentCamera
	if not camera or not folder then
		return nil
	end
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	local instance = if result then result.Instance else nil
	while instance and instance.Parent ~= folder do
		instance = instance.Parent
	end
	return if instance and instance:IsA("Model") and views[instance] then instance else nil
end

local function click(model: Model)
	local id = model:GetAttribute("BlockId")
	local now = os.clock()
	if typeof(id) == "string" and #id > 0 and #id <= 64 and now - lastClick >= 0.1 then
		lastClick = now
		NetClient.Fire("RequestClick", id)
	end
end

function BlockController.Init()
	if initialized then
		return
	end
	initialized = true
	NetClient.On("BlockHit", function(blockId: string, _hp: number, _maxHp: number, damage: number, attacker: Player)
		for model, view in views do
			local part = model.PrimaryPart
			if model:GetAttribute("BlockId") ~= blockId or not part or not visible(part.Position) then
				continue
			end
			local own = attacker == Players.LocalPlayer
			if view.shake then
				view.shake:Cancel()
			end
			if view.origin then
				model:PivotTo(view.origin)
			end
			if view.offset then
				view.offset:Destroy()
			end
			local origin = model:GetPivot()
			local offset = Instance.new("CFrameValue")
			offset.Value = CFrame.identity
			view.origin = origin
			view.offset = offset
			offset.Changed:Connect(function(value)
				if views[model] == view then
					model:PivotTo(origin * value)
				end
			end)
			local shake = TweenService:Create(
				offset,
				TweenInfo.new(0.045, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true),
				{ Value = CFrame.Angles(0, 0, math.rad(if own then 5 else 3)) }
			)
			view.shake = shake
			shake.Completed:Connect(function()
				if view.shake == shake then
					model:PivotTo(origin)
					view.shake = nil
					view.origin = nil
					view.offset = nil
					offset:Destroy()
				end
			end)
			shake:Play()
			local anchor = effectPart(part.Position)
			particles(anchor, if own then 8 else 4)
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(110, 45)
			gui.Adornee = anchor
			gui.MaxDistance = 60
			gui.AlwaysOnTop = true
			gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
			gui.Parent = anchor
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Text = `+{Format.abbreviate(damage)}`
			label.TextSize = if own then 32 else 24
			label.TextColor3 = Color3.fromRGB(255, 220, 95)
			label.TextStrokeTransparency = 0.3
			label.Parent = gui
			TweenService:Create(gui, TweenInfo.new(0.7), { StudsOffsetWorldSpace = Vector3.new(0, 5, 0) }):Play()
			TweenService:Create(label, TweenInfo.new(0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			Debris:AddItem(anchor, 0.85)
			break
		end
	end)
	NetClient.On("BlockBroken", function(_blockId: string, position: Vector3, _blockType: string)
		if not visible(position) then
			return
		end
		local anchor = effectPart(position)
		particles(anchor, 30)
		local sound = Instance.new("Sound")
		-- TODO: definir asset de som de doce quebrando quando estiver aprovado.
		sound.SoundId = ""
		sound.Parent = anchor
		if sound.SoundId ~= "" then
			sound:Play()
		end
	end)
end

function BlockController.Start()
	if started then
		return
	end
	started = true
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or heldInput then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local model = target(Vector2.new(input.Position.X, input.Position.Y))
		if model then
			heldInput = input
			heldModel = model
			click(model)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == heldInput then
			heldInput = nil
			heldModel = nil
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		heldInput = nil
		heldModel = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local input, model = heldInput, heldModel
			if input and model then
				local position = if input.UserInputType == Enum.UserInputType.Touch
					then Vector2.new(input.Position.X, input.Position.Y)
					-- GetMouseLocation inclui a barra superior; ScreenPointToRay espera sem ela.
					else UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
				if target(position) == model then
					click(model)
				else
					heldModel = nil
				end
			end
		end
	end)
	task.spawn(function()
		local blocksFolder = Workspace:WaitForChild("Blocks")
		folder = blocksFolder
		blocksFolder.ChildAdded:Connect(add)
		blocksFolder.ChildRemoved:Connect(function(instance)
			if instance:IsA("Model") then
				remove(instance)
			end
		end)
		for _, instance in blocksFolder:GetChildren() do
			add(instance)
		end
	end)
end

return BlockController
