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
		HudController.Toast("Shop coming soon!", "info")
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
		Menus.Open(key)
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
		side.DailyBadge.Visible = available
	end)
	local bottom = BottomBar.Create(root, function()
		HudController.Toast("Coming soon!", "info")
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
			top.RebirthLabel.Text = "Rebirth [" .. Format.abbreviate(value) .. "]"
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
	local rebirthRegistered = false
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
		-- Reserva a área do RebirthToggleButton original apenas quando ele estiver visível.
		local toggleLeft = 0.98 * size.X - 126
		local rebirthTop = topInset + 0.37 * coreY - 52
		local rebirthBottom = topInset + 0.37 * coreY + 8
		local toggle = rebirthToggle
		local toggleHidden = toggle ~= nil and not toggle.Visible
		if
			not toggleHidden
			and toggle
			and toggle.Parent
			and toggle.AbsoluteSize.X > 0
			and toggle.AbsoluteSize.Y > 0
		then
			local togglePos = toggle.AbsolutePosition - screen.AbsolutePosition
			local toggleSize = toggle.AbsoluteSize
			toggleLeft = togglePos.X
			rebirthTop = togglePos.Y - 4
			rebirthBottom = togglePos.Y + toggleSize.Y + 4
		end
		local rebirthLeft = toggleLeft - 6
		local topY = if portrait
			then topReserve + 8
			elseif compact then (if topReserve > 0 then topInset + topReserve + 2 else 6)
			else topReserve + 2
		local avoidsRebirthTop = not toggleHidden and compact and (topY + 56 * factor) > rebirthTop
		local availableWidth = if avoidsRebirthTop
			then math.min(size.X - 262, math.max(260, rebirthLeft - 246))
			elseif compact then size.X - 262
			else size.X - 24
		local width = math.min(520, availableWidth / factor)
		top.Root.Size = UDim2.fromOffset(width, 62)
		local capsuleWidth = (width - 20) / 2
		for index, key in { "Coins", "Gems" } do
			local capsule = top.Labels[key].Parent :: Frame
			capsule.Size = UDim2.fromOffset(capsuleWidth, if compact then 56 else 62)
			capsule.Position = UDim2.fromOffset((index - 1) * (capsuleWidth + 20), 0)
			top.Labels[key].Size = UDim2.fromOffset(capsuleWidth - 118, 52)
			top.Labels[key].Position = UDim2.new(0, 56, 0.5, 0)
			local plus = capsule:FindFirstChild("Add" .. key) :: TextButton
			plus.Size = UDim2.fromOffset(56, 56)
			plus.Position = UDim2.new(0, capsuleWidth - 58, 0.5, 0)
		end
		local topRight = if avoidsRebirthTop then math.min(size.X - 12, rebirthLeft) else size.X - 12
		local topX = if compact then topRight - width * factor / 2 else size.X / 2
		top.Root.Position = UDim2.fromOffset(topX, topY)
		local sideFactor = if compact
			then 0.56
			elseif portrait then 0.72
			else math.clamp((size.Y - 145) / 268, 0.75, 0.95)
		side.Scale.Scale = sideFactor
		side.Root.Size = UDim2.fromOffset(176, 268)
		side.Root.AnchorPoint = if compact then Vector2.new(0, 0) else Vector2.new(0, 0.5)
		if compact then
			local sideHeight = 268 * sideFactor
			local minSideY = topInset + 6
			local maxSideY = math.max(minSideY, size.Y - 124 - sideHeight)
			local desiredSideY = topInset + (coreY - sideHeight) / 2
			side.Root.Position = UDim2.fromOffset(12, math.clamp(desiredSideY, minSideY, maxSideY))
		else
			side.Root.Position = UDim2.new(0, if portrait then 12 else 16, 0.5, 0)
		end
		bottom.Scale.Scale = bottomScale
		bottom.Root.Size = UDim2.fromOffset(440, bottomHeight)
		for _, button in bottom.Buttons do
			button.Size = UDim2.fromOffset(212, bottomHeight)
		end
		bottom.Root.Position = UDim2.new(0.5, 0, 1, -bottomMargin)
		-- Em paisagem, apenas um aviso ocupa a faixa central livre entre os controles.
		toastLimit = if compact then 1 elseif portrait then 2 else 3
		stack.ClipsDescendants = true
		local compactToastWidth = math.min(260, math.max(160, (size.X - 12 - 168 - 12 - size.X / 2) * 2))
		local stackTop = topY + 62 * factor + 10
		local portraitOverlapsRebirth = not toggleHidden
			and portrait
			and (stackTop + 110) > rebirthTop
			and stackTop < rebirthBottom
		local portraitToastWidth = if portraitOverlapsRebirth
			then math.clamp(toggleLeft - 8 - 16, 160, size.X - 32)
			else size.X - 32
		local portraitToastX = if portraitOverlapsRebirth then 16 + portraitToastWidth / 2 else size.X / 2
		stack.Size = UDim2.fromOffset(
			if compact then compactToastWidth elseif portrait then portraitToastWidth else 360,
			if compact then 52 elseif portrait then 110 else 168
		)
		stack.Position = if compact
			then UDim2.fromOffset(size.X / 2, bottomTopY - 62)
			elseif portrait then UDim2.fromOffset(portraitToastX, stackTop)
			else UDim2.fromOffset(size.X / 2, stackTop)
		local count = 0
		for _, child in stack:GetChildren() do
			if child:IsA("TextLabel") then
				count += 1
				if count > toastLimit then
					child:Destroy()
				end
			end
		end
		-- Selo Rebirth [N] só aparece após Register("Rebirth", setter); até lá fica escondido.
		top.Rebirth.Parent = root
		top.Rebirth.Visible = rebirthRegistered
		if not rebirthRegistered then
			return
		end
		top.Rebirth.AnchorPoint = Vector2.new(1, 0)
		local badgeWidth = if compact or portrait then 168 else 200
		local badgeHeight = if compact then 45 elseif portrait then 48 else 54
		top.Rebirth.Size = UDim2.fromOffset(badgeWidth, badgeHeight)
		local minBadgeY = if toggleHidden then topInset + 6 else rebirthBottom + 6
		local maxBadgeY = math.max(minBadgeY, bottomTopY - 8 - badgeHeight)
		local desiredBadgeY = topInset + (coreY - badgeHeight) / 2
		local badgeRightMargin = if compact or portrait then 12 else 16
		top.Rebirth.Position =
			UDim2.fromOffset(size.X - badgeRightMargin, math.clamp(desiredBadgeY, minBadgeY, maxBadgeY))
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
			table.insert(rebirthConns, button:GetPropertyChangedSignal("Visible"):Connect(resize))
			local function watchReadyBadge(child: Instance)
				if child.Name ~= "ReadyBadge" or not child:IsA("GuiObject") then
					return
				end
				local function syncReadyDot()
					top.ReadyDot.Visible = child.Visible
				end
				table.insert(rebirthConns, child:GetPropertyChangedSignal("Visible"):Connect(syncReadyDot))
				syncReadyDot()
			end
			local readyBadge = button:FindFirstChild("ReadyBadge")
			if readyBadge then
				watchReadyBadge(readyBadge)
			else
				top.ReadyDot.Visible = false
				local childConn: RBXScriptConnection? = nil
				childConn = button.ChildAdded:Connect(function(child: Instance)
					if child.Name == "ReadyBadge" and child:IsA("GuiObject") then
						if childConn then
							childConn:Disconnect()
							childConn = nil
						end
						watchReadyBadge(child)
					end
				end)
				if childConn then
					table.insert(rebirthConns, childConn)
				end
			end
		else
			top.ReadyDot.Visible = false
		end
		resize()
	end)
	Menus.SetRebirthRegisteredObserver(function(registered: boolean)
		rebirthRegistered = registered
		top.Rebirth.Visible = registered
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
					.. " coins"
					.. (if gems > 0 then " · +" .. Format.abbreviate(gems) .. " gems" else ""),
				"reward"
			)
		else
			HudController.Toast(Messages.message(code, payload), "error")
		end
	end))
end

return HudController
