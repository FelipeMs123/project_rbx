--!strict
-- StarterPlayerScripts.Client.UI.Daily.DailyUI | Dono: Squad A. Modal diário mobile-first e botão lateral.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DailyRewards = require(ReplicatedStorage.Shared.Config.DailyRewards)
local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Format = require(ReplicatedStorage.Shared.Logic.Format)

local DailyUI = {}
local screen: ScreenGui? = nil
local overlay: Frame? = nil
local badge: TextLabel? = nil
local claimButton: TextButton? = nil
local statusLabel: TextLabel? = nil
local cards: { TextLabel } = {}
local strokes: { UIStroke } = {}
local normalStatus = ""
local statusToken = 0
local statusVisible = false

local function decorate(target: TextLabel | TextButton)
	-- Luau strict não permite escrever propriedades numa união; as duas classes têm estas propriedades.
	local item = target :: any
	item.Active = true
	item.BorderSizePixel = 0
	item.Font = Enum.Font.GothamBold
	item.TextColor3 = Color3.new(1, 1, 1)
	item.TextScaled = true
	item.TextWrapped = true
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MinTextSize = 14
	textLimit.MaxTextSize = 20
	textLimit.Parent = item
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = item
end

function DailyUI.SetOpen(open: boolean)
	if overlay then
		overlay.Visible = open
	end
end

function DailyUI.ShowStatus(text: string)
	statusToken += 1
	local token = statusToken
	statusVisible = true
	if statusLabel then
		statusLabel.Text = text
	end
	task.delay(3, function()
		if statusToken == token then
			statusVisible = false
			if statusLabel then
				statusLabel.Text = normalStatus
			end
		end
	end)
end

function DailyUI.IsMounted(): boolean
	return screen ~= nil and screen.Parent ~= nil
end

function DailyUI.Create(onClaim: () -> ())
	if screen then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "DailyRewards"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	screen = gui
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local open = Instance.new("TextButton")
	open.Name = "OpenDaily"
	open.Text = "🎁 Diária"
	open.AnchorPoint = Vector2.new(0, 1)
	open.Position = UDim2.new(0.02, 0, 0.5, -64)
	open.Size = UDim2.fromOffset(120, 52)
	open.BackgroundColor3 = Color3.fromRGB(125, 65, 180)
	decorate(open)
	open.Parent = root
	local openLimit = Instance.new("UISizeConstraint")
	openLimit.MinSize = Vector2.new(96, 48)
	openLimit.Parent = open
	local openScale = Instance.new("UIScale")
	openScale.Parent = open
	local alert = Instance.new("TextLabel")
	alert.Name = "AvailableBadge"
	alert.Text = "!"
	alert.Size = UDim2.fromOffset(24, 24)
	alert.Position = UDim2.new(1, -16, 0, -8)
	alert.BackgroundColor3 = Color3.fromRGB(210, 45, 80)
	decorate(alert)
	alert.Active = false
	alert.Visible = false
	alert.Parent = open
	badge = alert
	local shade = Instance.new("Frame")
	shade.Name = "ModalOverlay"
	shade.Active = true
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.3
	shade.Size = UDim2.fromScale(1, 1)
	shade.Visible = false
	shade.ZIndex = 2
	shade.Parent = root
	overlay = shade
	local panel = Instance.new("Frame")
	panel.Name = "DailyModal"
	panel.Active = true
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.fromScale(0.5, 0.03)
	panel.BackgroundColor3 = Color3.fromRGB(35, 29, 55)
	panel.Parent = shade
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local title = Instance.new("TextLabel")
	title.Text = "Recompensa diária"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 4)
	title.Size = UDim2.new(1, -80, 0, 52)
	decorate(title)
	title.Parent = panel
	local close = Instance.new("TextButton")
	close.Text = "X"
	close.Size = UDim2.fromOffset(56, 56)
	close.Position = UDim2.new(1, -60, 0, 4)
	close.BackgroundColor3 = Color3.fromRGB(155, 50, 85)
	decorate(close)
	close.Parent = panel
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Days"
	grid.Active = true
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(12, 66)
	grid.Size = UDim2.new(1, -24, 1, -196)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollBarThickness = 6
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.Parent = grid
	for index, _ in DailyRewards.Days do
		local card = Instance.new("TextLabel")
		card.Name = `Day{index}`
		card.LayoutOrder = index
		decorate(card)
		card.Parent = grid
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = card
		cards[index] = card
		strokes[index] = stroke
	end
	local bonusNote = Instance.new("TextLabel")
	bonusNote.Name = "RebirthBonusNote"
	bonusNote.Text = "Valores já com bônus de rebirth"
	bonusNote.BackgroundTransparency = 1
	bonusNote.TextColor3 = Color3.fromRGB(185, 180, 200)
	bonusNote.Font = Enum.Font.Gotham
	bonusNote.TextScaled = true
	bonusNote.Size = UDim2.new(1, -24, 0, 20)
	bonusNote.Position = UDim2.new(0, 12, 1, -130)
	bonusNote.Parent = panel
	local bonusTextLimit = Instance.new("UITextSizeConstraint")
	bonusTextLimit.MinTextSize = 12
	bonusTextLimit.MaxTextSize = 14
	bonusTextLimit.Parent = bonusNote
	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, -24, 0, 40)
	status.Position = UDim2.new(0, 12, 1, -104)
	decorate(status)
	status.Parent = panel
	statusLabel = status
	local claim = Instance.new("TextButton")
	claim.Name = "ClaimDaily"
	claim.Size = UDim2.new(1, -24, 0, 56)
	claim.Position = UDim2.new(0, 12, 1, -60)
	decorate(claim)
	claim.Parent = panel
	claimButton = claim
	local function resize()
		local size = root.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local factor = math.clamp(math.min(size.X, size.Y) / 520, 0.85, 1.15)
		scale.Scale = factor
		openScale.Scale = factor
		openLimit.MinSize = Vector2.new(math.max(96, math.ceil(96 / factor)), math.max(48, math.ceil(48 / factor)))
		local width = math.min(620, size.X * 0.94 / factor)
		-- O rodapé do modal termina antes da faixa dos controles de movimento.
		panel.Size = UDim2.fromOffset(width, math.min(520, size.Y * 0.72 / factor))
		local columns = if width >= 500 then 4 else 2
		layout.CellSize = UDim2.fromOffset(math.floor((width - 32 - (columns - 1) * 8) / columns), 120)
		for _, descendant in panel:GetDescendants() do
			if descendant:IsA("UITextSizeConstraint") then
				descendant.MinTextSize = math.ceil((if descendant == bonusTextLimit then 12 else 14) / factor)
			end
		end
	end
	local resizeConnection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	open.Activated:Connect(function()
		DailyUI.SetOpen(not shade.Visible)
	end)
	close.Activated:Connect(function()
		DailyUI.SetOpen(false)
	end)
	claim.Activated:Connect(onClaim)
	gui.Destroying:Connect(function()
		resizeConnection:Disconnect()
		screen = nil
		overlay = nil
		badge = nil
		claimButton = nil
		statusLabel = nil
		cards = {}
		strokes = {}
		normalStatus = ""
		statusVisible = false
		statusToken += 1
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	resize()
end

function DailyUI.Refresh(
	loaded: boolean,
	available: boolean,
	nextDay: number?,
	claimed: number,
	pending: boolean,
	seconds: number,
	rebirths: number
)
	if not screen then
		return
	end
	if badge then
		badge.Visible = available
	end
	for index, reward in DailyRewards.Days do
		local selected = loaded and index == nextDay
		local collected = index <= claimed
		cards[index].Text = `Dia {reward.Day}{if reward.Special then " ★ Especial" else ""}\n{Format.abbreviate(
			Economy.applyCoinBonus(reward.Coins, rebirths, GameConfig.RebirthCoinBonus)
		)} moedas\n{reward.Gems} gemas\n{if selected
			then (if available then "Sua vez!" else "Amanhã")
			elseif collected then "✓ Já pegou"
			else ""}`
		cards[index].BackgroundColor3 = if selected then Color3.fromRGB(40, 115, 85) else Color3.fromRGB(55, 45, 75)
		strokes[index].Color = if selected
			then Color3.fromRGB(100, 255, 175)
			elseif reward.Special then Color3.fromRGB(255, 210, 75)
			else Color3.fromRGB(100, 85, 130)
		strokes[index].Thickness = if selected or reward.Special then 3 else 1
	end
	if statusLabel then
		local minutes = math.ceil(seconds / 60)
		normalStatus = if not loaded
			then "Carregando seus presentes..."
			elseif available then "Um presente para deixar seu dia mais doce!"
			else string.format("Volte em %02d:%02d", math.floor(minutes / 60), minutes % 60)
		if not statusVisible then
			statusLabel.Text = normalStatus
		end
	end
	if claimButton then
		local enabled = loaded and available and not pending
		claimButton.Interactable = enabled
		claimButton.AutoButtonColor = enabled
		claimButton.Text = if pending then "Pegando presente..." elseif available then "Resgatar!" else "Volte amanhã!"
		claimButton.BackgroundColor3 = if enabled then Color3.fromRGB(35, 135, 90) else Color3.fromRGB(85, 80, 100)
	end
end

return DailyUI
