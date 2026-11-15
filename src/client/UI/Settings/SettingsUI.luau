--!strict
-- StarterPlayerScripts.Client.UI.Settings.SettingsUI | Dono: Squad A. Controles de áudio acessíveis ao toque.
local Players = game:GetService("Players")
local SettingsUI = {}
local screen: ScreenGui? = nil
local buttons: { [string]: TextButton } = {}
local status: TextLabel? = nil
local statusVersion = 0

local function decorate(item: TextButton)
	item.Active = true
	item.BorderSizePixel = 0
	item.Font = Enum.Font.GothamBold
	item.TextColor3 = Color3.new(1, 1, 1)
	item.TextScaled = true
	item.TextWrapped = true
	local text = Instance.new("UITextSizeConstraint")
	text.MinTextSize = 14
	text.MaxTextSize = 22
	text.Parent = item
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = item
end

function SettingsUI.Refresh(music: boolean, sfx: boolean, loaded: boolean, pending: { [string]: boolean })
	for key, button in buttons do
		local enabled = if key == "Music" then music else sfx
		button.Text = (if key == "Music" then "🎵 Música" else "🔔 Sons")
			.. (if pending[key] then " · Salvando..." elseif enabled then " · ON (Ligado)" else " · OFF (Desligado)")
		button.Interactable = loaded and not pending[key]
		button.AutoButtonColor = button.Interactable
		button.BackgroundColor3 = if enabled then Color3.fromRGB(35, 135, 90) else Color3.fromRGB(85, 80, 100)
	end
end

function SettingsUI.ShowStatus(message: string)
	statusVersion += 1
	local version = statusVersion
	local label = status
	if not label then
		return
	end
	label.Text = message
	task.delay(3, function()
		if statusVersion == version and status == label then
			label.Text = ""
		end
	end)
end

function SettingsUI.Create(onToggle: (string) -> ())
	if screen then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SoundSettings"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 25
	screen = gui
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local open = Instance.new("TextButton")
	open.Name = "OpenSettings"
	open.Text = "🔊"
	open.AnchorPoint = Vector2.new(0, 1)
	open.Position = UDim2.new(0.02, 118, 0.5, -64)
	open.Size = UDim2.fromOffset(52, 48)
	open.BackgroundColor3 = Color3.fromRGB(125, 65, 180)
	decorate(open)
	open.Parent = root
	local openScale = Instance.new("UIScale")
	openScale.Parent = open
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(48, 48)
	limit.Parent = open
	local shade = Instance.new("Frame")
	shade.Name = "ModalOverlay"
	shade.Active = true
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.3
	shade.Size = UDim2.fromScale(1, 1)
	shade.Visible = false
	shade.ZIndex = 2
	shade.Parent = root
	local panel = Instance.new("Frame")
	panel.Name = "SettingsModal"
	panel.Active = true
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.fromScale(0.5, 0.03)
	panel.BackgroundColor3 = Color3.fromRGB(35, 29, 55)
	panel.Parent = shade
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local title = Instance.new("TextButton")
	title.Text = "Seus sons"
	title.BackgroundTransparency = 1
	title.AutoButtonColor = false
	title.Size = UDim2.new(1, -76, 0, 56)
	title.Position = UDim2.fromOffset(12, 0)
	decorate(title)
	title.Parent = panel
	local close = Instance.new("TextButton")
	close.Name = "CloseSettings"
	close.Text = "X"
	close.Size = UDim2.fromOffset(52, 52)
	close.Position = UDim2.new(1, -56, 0, 4)
	close.BackgroundColor3 = Color3.fromRGB(155, 50, 85)
	decorate(close)
	close.Parent = panel
	for index, key in { "Music", "Sfx" } do
		local button = Instance.new("TextButton")
		button.Name = key
		button.Size = UDim2.new(1, -24, 0, 56)
		button.Position = UDim2.fromOffset(12, 64 + (index - 1) * 64)
		decorate(button)
		button.Parent = panel
		buttons[key] = button
		button.Activated:Connect(function()
			onToggle(key)
		end)
	end
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.fromOffset(12, 192)
	statusLabel.Size = UDim2.new(1, -24, 0, 36)
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextColor3 = Color3.fromRGB(255, 160, 160)
	statusLabel.TextSize = 16
	statusLabel.TextWrapped = true
	statusLabel.Text = ""
	statusLabel.Parent = panel
	status = statusLabel
	open.Activated:Connect(function()
		shade.Visible = not shade.Visible
	end)
	close.Activated:Connect(function()
		shade.Visible = false
	end)
	local dailyButton: GuiObject? = nil
	local dailySizeConnection: RBXScriptConnection? = nil
	local function resize()
		local size = root.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local factor = math.clamp(math.min(size.X, size.Y) / 520, 0.85, 1.15)
		scale.Scale = factor
		openScale.Scale = factor
		limit.MinSize = Vector2.new(math.ceil(48 / factor), math.ceil(48 / factor))
		panel.Size = UDim2.fromOffset(math.min(360, size.X * 0.94 / factor), 232)
		local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
		local daily = if playerGui then playerGui:FindFirstChild("OpenDaily", true) else nil
		local nextDaily = if daily and daily:IsA("GuiObject") then daily else nil
		if nextDaily ~= dailyButton then
			if dailySizeConnection then
				dailySizeConnection:Disconnect()
			end
			dailyButton = nextDaily
			dailySizeConnection = if nextDaily
				then nextDaily:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
				else nil
		end
		local width = if daily
				and daily:IsA("GuiObject")
				and daily.AbsoluteSize.X > 0
			then daily.AbsoluteSize.X / factor
			else 110
		open.Position = UDim2.new(0.02, width + 8, 0.5, -64)
		for _, item in gui:GetDescendants() do
			if item:IsA("UITextSizeConstraint") then
				item.MinTextSize = math.ceil(14 / factor)
			end
		end
	end
	local connection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local addedConnection = playerGui.DescendantAdded:Connect(function(item)
		if item.Name == "OpenDaily" then
			task.defer(resize)
		end
	end)
	local removingConnection = playerGui.DescendantRemoving:Connect(function(item)
		if item == dailyButton then
			task.defer(resize)
		end
	end)
	gui.Destroying:Connect(function()
		connection:Disconnect()
		addedConnection:Disconnect()
		removingConnection:Disconnect()
		if dailySizeConnection then
			dailySizeConnection:Disconnect()
		end
		screen = nil
		status = nil
		table.clear(buttons)
	end)
	SettingsUI.Refresh(false, false, false, {})
	gui.Parent = playerGui
	resize()
end

return SettingsUI
