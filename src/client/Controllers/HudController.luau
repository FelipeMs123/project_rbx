--!strict
-- StarterPlayerScripts.Client.Controllers.HudController | Dono: Squad A. Saldos e avisos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TopBar = require(script.Parent.Parent.UI.Hud.TopBar)
local SideMenu = require(script.Parent.Parent.UI.Hud.SideMenu)
local BottomBar = require(script.Parent.Parent.UI.Hud.BottomBar)
local DailyUI = require(script.Parent.Parent.UI.Daily.DailyUI)
local DataController = require(script.Parent.DataController)
local NetClient = require(script.Parent.Parent.Net.NetClient)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Messages = require(script.Parent.Parent.UI.Hud.Messages)

local HudController = {}
local gui: ScreenGui? = nil
local toastStack: Frame? = nil
local topReserve = 0
local resizeHud: (() -> ())? = nil
local pending: { { text: string, kind: string } } = {}
local colors =
	{ info = Color3.fromRGB(50, 70, 110), error = Color3.fromRGB(165, 45, 65), reward = Color3.fromRGB(30, 115, 80) }

local function label(parent: Instance, text: string): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundColor3 = Color3.fromRGB(35, 29, 55)
	item.BackgroundTransparency = 0.1
	item.TextColor3 = Color3.new(1, 1, 1)
	item.Font = Enum.Font.GothamBold
	item.TextScaled = true
	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MaxTextSize = 19
	textConstraint.Parent = item
	item.TextWrapped = true
	item.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = item
	item.Parent = parent
	return item
end

function HudController.Toast(text: string, kind: string)
	local stack = toastStack
	if not stack then
		table.insert(pending, { text = text, kind = kind })
		return
	end
	local item = label(stack, text)
	item.Active = false
	item.Size = UDim2.new(1, 0, 0, 52)
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.BackgroundColor3 = colors[kind] or colors.info
	task.delay(2.5, function()
		item:Destroy()
	end)
end

function HudController.SetTopReserve(pixels: number)
	if pixels ~= pixels or math.abs(pixels) == math.huge then
		return
	end
	topReserve = math.max(0, pixels)
	if resizeHud then
		resizeHud()
	end
end

function HudController.Init()
	-- O registro fica em Start: NetClient.On pode esperar a replicação do remote.
end

function HudController.Start()
	if gui then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui then
		warn("[HUD] PlayerGui indisponível após 10 segundos.")
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "CandyHud"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui = screen
	local toastScreen = Instance.new("ScreenGui")
	toastScreen.Name = "CandyToasts"
	toastScreen.DisplayOrder = 100
	toastScreen.ResetOnSpawn = false
	toastScreen.IgnoreGuiInset = screen.IgnoreGuiInset
	toastScreen.ScreenInsets = screen.ScreenInsets
	toastScreen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = screen
	local toastRoot = Instance.new("Frame")
	toastRoot.BackgroundTransparency = 1
	toastRoot.Active = false
	toastRoot.Size = UDim2.fromScale(1, 1)
	toastRoot.Parent = toastScreen
	local function shop()
		HudController.Toast("Loja em breve!", "info")
	end
	local function openPets()
		-- Sem evento público de abertura: preserva o handler original da Squad B,
		-- que também atualiza a grade. O jogador aciona o botão destacado.
		local button = playerGui:FindFirstChild("PetsToggleButton", true)
		if button and button:IsA("GuiButton") then
			button.Visible = true
			local highlight = button:FindFirstChild("HudPetsHighlight")
			if not highlight then
				local stroke = Instance.new("UIStroke")
				stroke.Name = "HudPetsHighlight"
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Color = Color3.fromRGB(255, 207, 50)
				stroke.Thickness = 4
				stroke.Parent = button
				task.delay(2.5, function()
					stroke:Destroy()
				end)
			end
			HudController.Toast("Toque no botão Pets destacado para abrir o inventário.", "info")
		else
			HudController.Toast("O inventário ainda está carregando. Tente de novo.", "info")
		end
	end
	local top = TopBar.Create(root, shop, function()
		local modal = playerGui:FindFirstChild("RebirthModal", true)
		if modal and modal:IsA("GuiObject") then
			local pets = playerGui:FindFirstChild("PetsModal", true)
			if pets and pets:IsA("GuiObject") then
				pets.Visible = false
			end
			modal.Visible = true
		else
			HudController.Toast("O rebirth ainda está carregando. Tente de novo.", "info")
		end
	end)
	local side = SideMenu.Create(root, {
		Shop = shop,
		Pets = openPets,
		Inventory = openPets,
		Daily = function()
			DailyUI.SetOpen(true)
		end,
		Settings = function()
			local settings = playerGui:FindFirstChild("SoundSettings")
			local overlay = if settings then settings:FindFirstChild("ModalOverlay", true) else nil
			if overlay and overlay:IsA("GuiObject") then
				overlay.Visible = true
			end
		end,
	})
	local bottom = BottomBar.Create(root, function()
		HudController.Toast("Disponível em breve!", "info")
	end)
	for _, key in { "Coins", "Gems" } do
		local previous: number? = nil
		local animation: Tween? = nil
		DataController.Observe(key, function(value: any)
			if type(value) ~= "number" then
				return
			end
			top.Labels[key].Text = Format.abbreviate(value)
			if previous and value > previous then
				if animation then
					animation:Cancel()
				end
				top.Pops[key].Scale = 1.04
				local tween =
					TweenService:Create(top.Pops[key], TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 })
				animation = tween
				tween:Play()
			end
			previous = value
		end)
	end
	DataController.Observe("Rebirths", function(value: any)
		if type(value) == "number" then
			top.Rebirth.Text = "Rebirth: " .. Format.abbreviate(value)
		end
	end)
	-- Esconde somente os atalhos: os modais e handlers continuam na Squad B.
	local function hideLegacy(item: Instance)
		if
			item:IsA("GuiObject")
			and (item.Name == "RebirthToggleButton" or item.Name == "OpenDaily" or item.Name == "OpenSettings")
		then
			item.Visible = false
		end
	end
	playerGui.DescendantAdded:Connect(hideLegacy)
	for _, item in playerGui:GetDescendants() do
		hideLegacy(item)
	end
	local stack = Instance.new("Frame")
	stack.BackgroundTransparency = 1
	stack.Active = false
	stack.AnchorPoint = Vector2.new(0.5, 0)
	-- Topo central, estreito o bastante para não encostar no chat (canto superior esquerdo).
	stack.Position = UDim2.new(0.5, 0, 0, topReserve)
	stack.Size = UDim2.fromScale(0.5, 0.6)
	stack.Parent = toastRoot
	local stackLimit = Instance.new("UISizeConstraint")
	stackLimit.MaxSize = Vector2.new(360, math.huge)
	stackLimit.Parent = stack
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = stack
	toastStack = stack
	local function resize()
		local size = root.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local compact = size.Y < 600
		-- Escalas mínimas preservam alvos de 44 px; a coluna compacta fica
		-- para dentro do analógico e abaixo do primeiro quarto da tela.
		local factor = math.clamp(size.X / 1100, 0.8, 1.15)
		top.Scale.Scale = factor
		local width = math.min(520, (size.X - 24) / factor)
		top.Root.Size = UDim2.fromOffset(width, 128)
		local capsuleWidth = (width - 20) / 2
		for index, key in { "Coins", "Gems" } do
			local capsule = top.Labels[key].Parent :: Frame
			capsule.Size = UDim2.fromOffset(capsuleWidth, 62)
			capsule.Position = UDim2.fromOffset((index - 1) * (capsuleWidth + 20), 0)
			top.Labels[key].Size = UDim2.fromOffset(capsuleWidth - 120, 56)
			local plus = capsule:FindFirstChild("Add" .. key) :: TextButton
			plus.Position = UDim2.fromOffset(capsuleWidth - 58, 3)
		end
		top.Root.Position =
			UDim2.new(0.5, if compact then math.max(0, 184 - (size.X - width * factor) / 2) else 0, 0, topReserve + 8)
		local sideFactor = if compact then 0.75 else math.clamp(size.Y / 800, 0.85, 1.1)
		side.Scale.Scale = sideFactor
		side.Root.Position = UDim2.fromOffset(if compact then 128 else 14, math.max(size.Y * 0.25, 84))
		for _, child in side.Root:GetChildren() do
			if child:IsA("TextButton") then
				local index = table.find(
					{ "DailyButton", "ShopButton", "PetsButton", "InventoryButton", "SettingsButton" },
					child.Name
				) or 1
				child.Size = UDim2.fromOffset(
					if compact then 60 else 96,
					if compact then 60 else (if index == 1 then 60 else 92)
				)
				child.Position = UDim2.fromOffset(
					0,
					if compact then (index - 1) * 64 else (if index == 1 then 0 else 70 + (index - 2) * 100)
				)
			end
		end
		bottom.Scale.Scale = math.clamp((size.X - 396) / 440, 0.7, 1.15)
		bottom.Root.Position = UDim2.new(0.5, if compact then 38 else 0, 1, -18)
		stack.Position = UDim2.new(0.5, 0, 0, topReserve + 16 + 128 * factor)
	end
	resizeHud = resize
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	screen.Parent = playerGui
	toastScreen.Parent = playerGui
	resize()
	for _, entry in pending do
		HudController.Toast(entry.text, entry.kind)
	end
	table.clear(pending)
	NetClient.On("Notify", function(code: any, payload: any)
		if code == "REWARD" and type(payload) == "table" then
			local coins = if type(payload.coins) == "number" then payload.coins else 0
			local gems = if type(payload.gems) == "number" then payload.gems else 0
			if coins == 0 and gems == 0 then
				return
			end
			HudController.Toast(
				"+"
					.. Format.abbreviate(coins)
					.. " moedas"
					.. (if gems > 0 then " · +" .. Format.abbreviate(gems) .. " gemas" else ""),
				"reward"
			)
		else
			HudController.Toast(Messages.message(code, payload), "error")
		end
	end)
end

return HudController
