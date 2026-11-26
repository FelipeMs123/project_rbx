--!strict
-- StarterPlayerScripts.Client.Controllers.HudController | Dono: Squad A. Saldos e avisos.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local TopBar = require(script.Parent.Parent.UI.Hud.TopBar)
local SideMenu = require(script.Parent.Parent.UI.Hud.SideMenu)
local BottomBar = require(script.Parent.Parent.UI.Hud.BottomBar)
local Menus = require(script.Parent.Parent.UI.Hud.MenuCoordinator)
local DataController = require(script.Parent.DataController)
local NetClient = require(script.Parent.Parent.Net.NetClient)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Messages = require(script.Parent.Parent.UI.Hud.Messages)

local HudController = {}
local gui: ScreenGui? = nil
local toastStack: Frame? = nil
local topReserve = 0
local resizeHud: (() -> ())? = nil
local toastLimit = 3
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
	local items: { TextLabel } = {}
	for _, child in stack:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(items, child)
		end
	end
	while #items >= toastLimit do
		local oldest = table.remove(items, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local item = label(stack, text)
	item.Active = false
	item.Size = UDim2.new(1, 0, 0, 52)
	item.AutomaticSize = Enum.AutomaticSize.None
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
	screen.DisplayOrder = -1
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
	local disconnectors: { () -> () } = {}
	-- Observe usa Signal.Connection; os demais eventos usam RBXScriptConnection.
	local function track(connection: any)
		table.insert(disconnectors, function()
			connection:Disconnect()
		end)
	end
	local unmountMenus = Menus.Mount(playerGui)
	local function openMenu(key: string)
		if not Menus.Open(key) then
			HudController.Toast("Use o botão Rebirth original para abrir a confirmação.", "info")
		end
	end
	local function openPets()
		openMenu("Pets")
	end
	local top = TopBar.Create(root, shop, function()
		openMenu("Rebirth")
	end)
	local side = SideMenu.Create(root, {
		Shop = shop,
		Pets = openPets,
		Inventory = openPets,
		Daily = function()
			openMenu("Daily")
		end,
		Settings = function()
			openMenu("Settings")
		end,
	})
	Menus.SetDailyBadge(function(available: boolean)
		side.DailyIcon.Text = if available then "🎁  !" else "🎁"
	end)
	local bottom = BottomBar.Create(root, function()
		HudController.Toast("Disponível em breve!", "info")
	end)
	for _, key in { "Coins", "Gems" } do
		local previous: number? = nil
		local animation: Tween? = nil
		track(DataController.Observe(key, function(value: any)
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
		end))
	end
	track(DataController.Observe("Rebirths", function(value: any)
		if type(value) == "number" then
			top.Rebirth.Text = "Rebirth: " .. Format.abbreviate(value)
		end
	end))
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
	local rebirthToggle: GuiObject? = nil
	local rebirthConns: { RBXScriptConnection } = {}
	local function clearRebirthConns()
		for _, connection in rebirthConns do
			connection:Disconnect()
		end
		table.clear(rebirthConns)
	end
	table.insert(disconnectors, clearRebirthConns)
	local function resize()
		local size = root.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local camera = Workspace.CurrentCamera
		local guiTopInset = GuiService:GetGuiInset().Y
		local coreViewportY = if camera and camera.ViewportSize.Y > 0
			then camera.ViewportSize.Y - guiTopInset
			elseif screen.ScreenInsets == Enum.ScreenInsets.DeviceSafeInsets then size.Y - guiTopInset
			else size.Y
		local compact = coreViewportY < 440
		local targetInsets = if compact then Enum.ScreenInsets.DeviceSafeInsets else Enum.ScreenInsets.CoreUISafeInsets
		if screen.ScreenInsets ~= targetInsets then
			screen.ScreenInsets = targetInsets
			toastScreen.ScreenInsets = targetInsets
			return
		end
		local topInset = if compact then guiTopInset else 0
		local coreY = math.max(1, size.Y - topInset)
		local portrait = size.X < 620 and not compact
		local bottomScale = math.clamp((size.X - 396) / 440, 0.7, 1.15)
		local bottomHeight = if compact then math.max(48, math.ceil(44 / bottomScale)) else 64
		local bottomMargin = if portrait then 150 else 18
		local bottomTopY = size.Y - bottomMargin - bottomHeight * bottomScale
		local factor = math.clamp(size.X / 1100, 0.8, 1.15)
		top.Scale.Scale = factor
		-- Reserva a área do RebirthToggleButton original em paisagem compacta (leitura real ou fallback por fórmula).
		local rebirthLeft = 0.98 * size.X - 132
		local rebirthTop = topInset + 0.37 * coreY - 52
		local rebirthBottom = topInset + 0.37 * coreY + 8
		local toggle = rebirthToggle
		if toggle and toggle.Parent and toggle.AbsoluteSize.X > 0 and toggle.AbsoluteSize.Y > 0 then
			local togglePos = toggle.AbsolutePosition - screen.AbsolutePosition
			local toggleSize = toggle.AbsoluteSize
			rebirthLeft = togglePos.X - 6
			rebirthTop = togglePos.Y - 4
			rebirthBottom = togglePos.Y + toggleSize.Y + 4
		end
		local topY = if portrait
			then math.max(260, topReserve + 8)
			elseif compact then (if topReserve > 0 then topInset + topReserve + 2 else 6)
			else topReserve + 2
		local avoidsRebirthTop = compact and (topY + 56 * factor) > rebirthTop
		local availableWidth = if avoidsRebirthTop
			then math.min(size.X - 262, math.max(260, rebirthLeft - 246))
			elseif compact then size.X - 262
			else size.X - 24
		local width = math.min(520, availableWidth / factor)
		top.Root.Size = UDim2.fromOffset(width, 128)
		local capsuleWidth = (width - 20) / 2
		for index, key in { "Coins", "Gems" } do
			local capsule = top.Labels[key].Parent :: Frame
			capsule.Size = UDim2.fromOffset(capsuleWidth, if compact then 56 else 62)
			capsule.Position = UDim2.fromOffset((index - 1) * (capsuleWidth + 20), 0)
			top.Labels[key].Size = UDim2.fromOffset(capsuleWidth - 120, 56)
			top.Labels[key].Position = UDim2.fromOffset(58, if compact then 0 else 3)
			local plus = capsule:FindFirstChild("Add" .. key) :: TextButton
			plus.Position = UDim2.fromOffset(capsuleWidth - 58, if compact then 0 else 3)
		end
		local topRight = if avoidsRebirthTop then math.min(size.X - 12, rebirthLeft) else size.X - 12
		local topX = if compact then topRight - width * factor / 2 else size.X / 2
		top.Root.Position = UDim2.fromOffset(topX, topY)
		local sideFactor = if compact
			then 0.75
			elseif portrait then 0.8
			else math.clamp((size.Y - 145) / 492, 0.75, 0.95)
		side.Scale.Scale = sideFactor
		side.Root.AnchorPoint = if compact or portrait then Vector2.new(0, 0) else Vector2.new(0, 0.5)
		local smallMenu = compact or portrait
		side.Root.Size = if compact
			then UDim2.fromOffset(316, 60)
			elseif portrait then UDim2.fromOffset(124, 188)
			else UDim2.fromOffset(108, 492)
		local sideY = if compact
			then math.max(bottomTopY - 117, rebirthBottom)
			else (if portrait then topY + 128 * factor + 12 else math.max(size.Y * 0.25, 84))
		side.Root.Position = if smallMenu
			then UDim2.fromOffset(if compact then size.X - 249 else 14, sideY)
			else UDim2.new(0, 16, 0.5, 0)
		for _, child in side.Root:GetChildren() do
			if child:IsA("TextButton") then
				local index = table.find(
					{ "DailyButton", "ShopButton", "PetsButton", "InventoryButton", "SettingsButton" },
					child.Name
				) or 1
				child.Size = UDim2.fromOffset(
					if smallMenu then 60 else 108,
					if smallMenu then 60 else (if index == 1 then 60 else 100)
				)
				local x = if compact then (index - 1) * 64 elseif portrait then ((index - 1) % 2) * 64 else 0
				local y = if compact
					then 0
					elseif portrait then math.floor((index - 1) / 2) * 64
					else (if index == 1 then 0 else 68 + (index - 2) * 108)
				child.Position = UDim2.fromOffset(x, y)
			end
		end
		bottom.Scale.Scale = bottomScale
		bottom.Root.Size = UDim2.fromOffset(440, bottomHeight)
		for _, button in bottom.Buttons do
			button.Size = UDim2.fromOffset(212, bottomHeight)
		end
		bottom.Root.Position = UDim2.new(0.5, if compact then 38 else 0, 1, -bottomMargin)
		-- Em paisagem, apenas um aviso ocupa a faixa central livre entre os controles.
		toastLimit = if compact then 1 elseif portrait then 2 else 3
		stack.ClipsDescendants = true
		local compactToastWidth = math.min(220, math.max(140, (size.X - 12 - 168 - 8 - (size.X / 2 + 38)) * 2))
		stack.Size = UDim2.fromOffset(
			if compact then compactToastWidth elseif portrait then size.X - 140 else 360,
			if compact then 52 elseif portrait then 110 else 168
		)
		stack.Position = if compact
			then UDim2.fromOffset(size.X / 2 + 38, bottomTopY - 62)
			elseif portrait then UDim2.fromOffset((size.X + 120) / 2, sideY)
			else UDim2.fromOffset(size.X / 2, topY + 128 * factor + 8)
		local count = 0
		for _, child in stack:GetChildren() do
			if child:IsA("TextLabel") then
				count += 1
				if count > toastLimit then
					child:Destroy()
				end
			end
		end
		-- O selo sai da barra superior na paisagem para liberar o centro e alinhar à direita abaixo do menu.
		top.Rebirth.Parent = if compact then root else top.Root
		top.Rebirth.Visible = true
		top.Rebirth.AnchorPoint = if compact then Vector2.new(1, 0) else Vector2.new(0.5, 0)
		top.Rebirth.Size = UDim2.fromOffset(if compact then 168 else 210, if compact then 45 else 56)
		top.Rebirth.Position = if compact
			then UDim2.fromOffset(size.X - 12, sideY + 60 * sideFactor + 6)
			else UDim2.new(0.5, 0, 0, 72)
	end
	screen.Destroying:Connect(function()
		for _, disconnect in disconnectors do
			disconnect()
		end
		unmountMenus()
		gui = nil
		resizeHud = nil
		toastStack = nil
		toastScreen:Destroy()
	end)
	track(toastScreen.Destroying:Connect(function()
		toastStack = nil
		if gui == screen then
			screen:Destroy()
		end
	end))
	resizeHud = resize
	track(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	track(root:GetPropertyChangedSignal("AbsolutePosition"):Connect(resize))
	track(stack.ChildAdded:Connect(resize))
	track(stack.ChildRemoved:Connect(resize))
	screen.Parent = playerGui
	toastScreen.Parent = playerGui
	Menus.SetRebirthToggleObserver(function(button: GuiObject?)
		clearRebirthConns()
		rebirthToggle = button
		if button then
			table.insert(rebirthConns, button:GetPropertyChangedSignal("AbsolutePosition"):Connect(resize))
			table.insert(rebirthConns, button:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
		end
		resize()
	end)
	for _, entry in pending do
		HudController.Toast(entry.text, entry.kind)
	end
	table.clear(pending)
	track(NetClient.On("Notify", function(code: any, payload: any)
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
	end))
end

return HudController
