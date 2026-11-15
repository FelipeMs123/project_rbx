--!strict
-- RebirthUI.luau (StarterPlayerScripts.Client.UI.Rebirth.RebirthUI)
-- Dono: Squad B. Interface mobile-first de Rebirth com barra de progresso, prévia e confirmação em 2 etapas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local HudController = require(script.Parent.Parent.Parent.Controllers.HudController)
local RebirthHelpers = require(script.Parent.RebirthHelpers)

local MIN_UI_SCALE = 0.85
local MAX_UI_SCALE = 1.25

export type RebirthViewState = {
	Coins: number,
	Rebirths: number,
	Gems: number,
	IsBusy: boolean,
}

local RebirthUI = {}

local rebirthGui: ScreenGui? = nil
local toggleButton: TextButton? = nil
local toggleBadge: TextLabel? = nil
local modalFrame: Frame? = nil
local progressFill: Frame? = nil
local progressTextLabel: TextLabel? = nil
local currentRebirthsLabel: TextLabel? = nil
local nextRebirthsLabel: TextLabel? = nil
local currentMultiplierLabel: TextLabel? = nil
local nextMultiplierLabel: TextLabel? = nil
local gemRewardLabel: TextLabel? = nil
local stepOnePanel: Frame? = nil
local stepTwoPanel: Frame? = nil
local startRebirthButton: TextButton? = nil
local confirmButton: TextButton? = nil
local cancelButton: TextButton? = nil

local uiScales: { UIScale } = {}
local connections: { RBXScriptConnection } = {}
local currentCameraConnection: RBXScriptConnection? = nil
local cameraConnection: RBXScriptConnection? = nil
local rebirthGuiLifecycleConnections: { RBXScriptConnection } = {}
local playerGuiWatchConnections: { RBXScriptConnection } = {}
local petGuiWatchConnections: { RBXScriptConnection } = {}
local petsModalWatchConnections: { RBXScriptConnection } = {}
local watchedPetGui: Instance? = nil
local watchedPetsModal: GuiObject? = nil
local isCleaningUp = false

local confirmCallback: (() -> ())? = nil
local latestState: RebirthViewState = {
	Coins = 0,
	Rebirths = 0,
	Gems = 0,
	IsBusy = false,
}

local function computeResponsiveScale(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return 1
	end
	local ratio = math.min(viewport.X / 1280, viewport.Y / 720)
	return math.clamp(ratio, MIN_UI_SCALE, MAX_UI_SCALE)
end

local function updateAllScales()
	local scaleValue = computeResponsiveScale()
	for _, scaleObj in uiScales do
		scaleObj.Scale = scaleValue
	end
end

local function bindCameraViewport()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateAllScales)
	end
	updateAllScales()
end

local function attachResponsiveScale(target: GuiObject)
	local scaleObj = Instance.new("UIScale")
	scaleObj.Scale = computeResponsiveScale()
	scaleObj.Parent = target
	table.insert(uiScales, scaleObj)
end

local function addCorner(parent: Instance, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

local function addStroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function formatMultiplierText(value: number): string
	if value == math.floor(value) then
		return `{value}x`
	end
	local text = string.format("%.1f", value)
	text = string.gsub(text, "%.0$", "")
	return `{text}x`
end

local function collapseOtherMenus()
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local eggsGui = playerGui:FindFirstChild("EggsGui")
	if eggsGui then
		local eggPanel = eggsGui:FindFirstChild("EggPromptPanel")
		if eggPanel and eggPanel:IsA("GuiObject") and eggPanel.Visible then
			eggPanel.Visible = false
		end
	end

	local petGui = playerGui:FindFirstChild("PetInventoryGui")
	if petGui then
		for _, descendant in petGui:GetDescendants() do
			if descendant:IsA("GuiObject") and descendant.Visible then
				local lowerName = string.lower(descendant.Name)
				if
					string.find(lowerName, "panel", 1, true)
					or string.find(lowerName, "modal", 1, true)
					or string.find(lowerName, "window", 1, true)
					or lowerName == "inventoryframe"
					or lowerName == "mainframe"
				then
					descendant.Visible = false
				end
			end
		end
	end
end

local function setConfirmationStep(confirming: boolean)
	if stepOnePanel then
		stepOnePanel.Visible = not confirming
	end
	if stepTwoPanel then
		stepTwoPanel.Visible = confirming
	end
end

local function renderView()
	local cost = RebirthHelpers.computeCost(latestState.Rebirths, GameConfig)
	local mults = RebirthHelpers.computeMultipliers(latestState.Rebirths, GameConfig)
	local progress = RebirthHelpers.computeProgress(latestState.Coins, cost)

	if toggleBadge then
		toggleBadge.Visible = progress.CanRebirth
	end
	if toggleButton then
		toggleButton.BackgroundColor3 = if progress.CanRebirth
			then Color3.fromRGB(168, 85, 247)
			else Color3.fromRGB(78, 54, 130)
	end

	if progressFill then
		progressFill.Size = UDim2.fromScale(progress.Ratio, 1)
		progressFill.BackgroundColor3 = if progress.CanRebirth
			then Color3.fromRGB(52, 199, 89)
			else Color3.fromRGB(255, 184, 59)
	end
	if progressTextLabel then
		local coinsText = RebirthHelpers.formatShortNumber(latestState.Coins)
		local costText = RebirthHelpers.formatShortNumber(cost)
		progressTextLabel.Text = `Moedas: {coinsText} / {costText} ({progress.Percent}%)`
	end

	if currentRebirthsLabel then
		currentRebirthsLabel.Text = tostring(mults.CurrentRebirths)
	end
	if nextRebirthsLabel then
		nextRebirthsLabel.Text = tostring(mults.NextRebirths)
	end
	if currentMultiplierLabel then
		currentMultiplierLabel.Text = formatMultiplierText(mults.CurrentMultiplier)
	end
	if nextMultiplierLabel then
		nextMultiplierLabel.Text = formatMultiplierText(mults.NextMultiplier)
	end
	if gemRewardLabel then
		gemRewardLabel.Text = `+{mults.GemReward} Gemas`
	end

	if startRebirthButton then
		startRebirthButton.AutoButtonColor = not latestState.IsBusy
		if latestState.IsBusy then
			startRebirthButton.Text = "Fazendo Rebirth..."
			startRebirthButton.BackgroundColor3 = Color3.fromRGB(122, 130, 150)
		elseif progress.CanRebirth then
			startRebirthButton.Text = "Fazer Rebirth!"
			startRebirthButton.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
		else
			startRebirthButton.Text = "Fazer Rebirth!"
			startRebirthButton.BackgroundColor3 = Color3.fromRGB(120, 92, 148)
		end
	end

	if confirmButton then
		confirmButton.AutoButtonColor = not latestState.IsBusy
		if latestState.IsBusy then
			confirmButton.Text = "Enviando..."
			confirmButton.BackgroundColor3 = Color3.fromRGB(122, 130, 150)
		else
			confirmButton.Text = "Confirmar!"
			confirmButton.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
		end
	end
	if cancelButton then
		cancelButton.AutoButtonColor = not latestState.IsBusy
	end
end

local function createComparisonRow(
	parent: Instance,
	name: string,
	order: number,
	titleText: string
): (TextLabel, TextLabel)
	local row = Instance.new("Frame")
	row.Name = name
	row.LayoutOrder = order
	row.Size = UDim2.fromScale(1, 0.30)
	row.BackgroundColor3 = Color3.fromRGB(43, 35, 68)
	row.BorderSizePixel = 0
	row.Parent = parent
	addCorner(row, UDim.new(0, 8))

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.Parent = row

	local rowTitle = Instance.new("TextLabel")
	rowTitle.Name = "Label"
	rowTitle.Size = UDim2.fromScale(0.46, 1)
	rowTitle.BackgroundTransparency = 1
	rowTitle.Font = Enum.Font.GothamBold
	rowTitle.Text = titleText
	rowTitle.TextColor3 = Color3.fromRGB(224, 228, 255)
	rowTitle.TextScaled = true
	rowTitle.TextXAlignment = Enum.TextXAlignment.Left
	rowTitle.Parent = row

	local leftValue = Instance.new("TextLabel")
	leftValue.Name = "CurrentValue"
	leftValue.Position = UDim2.fromScale(0.48, 0)
	leftValue.Size = UDim2.fromScale(0.20, 1)
	leftValue.BackgroundTransparency = 1
	leftValue.Font = Enum.Font.GothamBold
	leftValue.Text = "0"
	leftValue.TextColor3 = Color3.fromRGB(255, 255, 255)
	leftValue.TextScaled = true
	leftValue.Parent = row

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Position = UDim2.fromScale(0.68, 0)
	arrow.Size = UDim2.fromScale(0.10, 1)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.Text = "→"
	arrow.TextColor3 = Color3.fromRGB(255, 214, 102)
	arrow.TextScaled = true
	arrow.Parent = row

	local rightValue = Instance.new("TextLabel")
	rightValue.Name = "NextValue"
	rightValue.Position = UDim2.fromScale(0.78, 0)
	rightValue.Size = UDim2.fromScale(0.22, 1)
	rightValue.BackgroundTransparency = 1
	rightValue.Font = Enum.Font.GothamBlack
	rightValue.Text = "1"
	rightValue.TextColor3 = Color3.fromRGB(130, 247, 173)
	rightValue.TextScaled = true
	rightValue.TextXAlignment = Enum.TextXAlignment.Right
	rightValue.Parent = row

	return leftValue, rightValue
end

local function createRebirthGui(playerGui: PlayerGui)
	local layout = RebirthHelpers.Layout
	local gui = Instance.new("ScreenGui")
	gui.Name = "RebirthGui"
	gui.DisplayOrder = 5
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	rebirthGui = gui

	-- Lateral direita acima do botão de Pets (0.98, 0.5) para não sobrepor moedas/gemas na esquerda nem o inventário de Pets.
	local toggle = Instance.new("TextButton")
	toggle.Name = "RebirthToggleButton"
	toggle.AnchorPoint = Vector2.new(1, 1)
	toggle.Position = UDim2.fromScale(layout.TogglePositionXScale, layout.TogglePositionYScale)
	toggle.Size = UDim2.fromScale(0.14, 0.09)
	toggle.BackgroundColor3 = Color3.fromRGB(78, 54, 130)
	toggle.AutoButtonColor = true
	toggle.Font = Enum.Font.GothamBlack
	toggle.Text = "Rebirth"
	toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggle.TextScaled = true
	toggle.Parent = gui
	toggleButton = toggle
	attachResponsiveScale(toggle)
	addCorner(toggle, UDim.new(0, 12))
	addStroke(toggle, Color3.fromRGB(214, 168, 255), 2, 0.15)

	local toggleConstraint = Instance.new("UISizeConstraint")
	toggleConstraint.MinSize = Vector2.new(112, 52)
	toggleConstraint.MaxSize = Vector2.new(200, 72)
	toggleConstraint.Parent = toggle

	local toggleTextConstraint = Instance.new("UITextSizeConstraint")
	toggleTextConstraint.MaxTextSize = 20
	toggleTextConstraint.MinTextSize = 12
	toggleTextConstraint.Parent = toggle

	local badge = Instance.new("TextLabel")
	badge.Name = "ReadyBadge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.92, 0.12)
	badge.Size = UDim2.fromScale(0.28, 0.48)
	badge.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
	badge.Font = Enum.Font.GothamBlack
	badge.Text = "!"
	badge.TextColor3 = Color3.fromRGB(255, 255, 255)
	badge.TextScaled = true
	badge.Visible = false
	badge.Parent = toggle
	toggleBadge = badge
	addCorner(badge, UDim.new(1, 0))
	addStroke(badge, Color3.fromRGB(255, 255, 255), 1.5, 0)

	local badgeRatio = Instance.new("UIAspectRatioConstraint")
	badgeRatio.AspectRatio = 1
	badgeRatio.Parent = badge

	local modal = Instance.new("Frame")
	modal.Name = "RebirthModal"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.fromScale(0.50, 0.58)
	modal.BackgroundColor3 = Color3.fromRGB(30, 23, 51)
	modal.BackgroundTransparency = 0.04
	modal.BorderSizePixel = 0
	modal.Active = true
	modal.Visible = false
	modal.Parent = gui
	modalFrame = modal
	attachResponsiveScale(modal)
	addCorner(modal, UDim.new(0, 18))
	addStroke(modal, Color3.fromRGB(196, 138, 255), 2.5, 0.1)

	local modalConstraint = Instance.new("UISizeConstraint")
	modalConstraint.MinSize = Vector2.new(layout.ModalMinSizeX, layout.ModalMinSizeY)
	modalConstraint.MaxSize = Vector2.new(layout.ModalMaxSizeX, layout.ModalMaxSizeY)
	modalConstraint.Parent = modal

	local modalPadding = Instance.new("UIPadding")
	modalPadding.PaddingTop = UDim.new(layout.ModalPaddingScale, 0)
	modalPadding.PaddingBottom = UDim.new(layout.ModalPaddingScale, 0)
	modalPadding.PaddingLeft = UDim.new(layout.ModalPaddingScale, 0)
	modalPadding.PaddingRight = UDim.new(layout.ModalPaddingScale, 0)
	modalPadding.Parent = modal

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.fromScale(1, layout.HeaderHeightScale)
	header.BackgroundTransparency = 1
	header.Parent = modal

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(0.80, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = "Rebirth"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.fromScale(1, 0.5)
	closeBtn.Size = UDim2.fromScale(0.14, 0.96)
	closeBtn.BackgroundColor3 = Color3.fromRGB(214, 78, 78)
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextScaled = true
	closeBtn.Parent = header
	addCorner(closeBtn, UDim.new(0, 10))

	local closeConstraint = Instance.new("UISizeConstraint")
	closeConstraint.MinSize = Vector2.new(layout.CloseButtonMinSize, layout.CloseButtonMinSize)
	closeConstraint.MaxSize = Vector2.new(64, 64)
	closeConstraint.Parent = closeBtn

	local progressBg = Instance.new("Frame")
	progressBg.Name = "ProgressBarBg"
	progressBg.Position = UDim2.fromScale(0, layout.ProgressPosYScale)
	progressBg.Size = UDim2.fromScale(1, layout.ProgressHeightScale)
	progressBg.BackgroundColor3 = Color3.fromRGB(20, 15, 36)
	progressBg.BorderSizePixel = 0
	progressBg.ClipsDescendants = true
	progressBg.Parent = modal
	addCorner(progressBg, UDim.new(0, 10))
	addStroke(progressBg, Color3.fromRGB(98, 78, 148), 1.5, 0.3)

	local fill = Instance.new("Frame")
	fill.Name = "ProgressFill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 184, 59)
	fill.BorderSizePixel = 0
	fill.Parent = progressBg
	progressFill = fill
	addCorner(fill, UDim.new(0, 10))

	local progressText = Instance.new("TextLabel")
	progressText.Name = "ProgressText"
	progressText.Size = UDim2.fromScale(1, 1)
	progressText.BackgroundTransparency = 1
	progressText.Font = Enum.Font.GothamBlack
	progressText.Text = "Moedas: 0 / 10K (0%)"
	progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
	progressText.TextStrokeTransparency = 0.45
	progressText.TextScaled = true
	progressText.ZIndex = 2
	progressText.Parent = progressBg
	progressTextLabel = progressText

	local progressTextConstraint = Instance.new("UITextSizeConstraint")
	progressTextConstraint.MaxTextSize = 16
	progressTextConstraint.MinTextSize = 10
	progressTextConstraint.Parent = progressText

	local compareCard = Instance.new("Frame")
	compareCard.Name = "ComparisonCard"
	compareCard.Position = UDim2.fromScale(0, layout.ComparePosYScale)
	compareCard.Size = UDim2.fromScale(1, layout.CompareHeightScale)
	compareCard.BackgroundColor3 = Color3.fromRGB(22, 16, 40)
	compareCard.BorderSizePixel = 0
	compareCard.Parent = modal
	addCorner(compareCard, UDim.new(0, 12))

	local comparePadding = Instance.new("UIPadding")
	comparePadding.PaddingTop = UDim.new(0.06, 0)
	comparePadding.PaddingBottom = UDim.new(0.06, 0)
	comparePadding.PaddingLeft = UDim.new(0.04, 0)
	comparePadding.PaddingRight = UDim.new(0.04, 0)
	comparePadding.Parent = compareCard

	local compareLayout = Instance.new("UIListLayout")
	compareLayout.SortOrder = Enum.SortOrder.LayoutOrder
	compareLayout.Padding = UDim.new(0.05, 0)
	compareLayout.Parent = compareCard

	currentRebirthsLabel, nextRebirthsLabel = createComparisonRow(compareCard, "RebirthsRow", 1, "Rebirths")
	currentMultiplierLabel, nextMultiplierLabel =
		createComparisonRow(compareCard, "MultiplierRow", 2, "Bônus de Moedas")

	local rewardRow = Instance.new("Frame")
	rewardRow.Name = "GemRewardRow"
	rewardRow.LayoutOrder = 3
	rewardRow.Size = UDim2.fromScale(1, 0.30)
	rewardRow.BackgroundColor3 = Color3.fromRGB(43, 35, 68)
	rewardRow.BorderSizePixel = 0
	rewardRow.Parent = compareCard
	addCorner(rewardRow, UDim.new(0, 8))

	local rewardPad = Instance.new("UIPadding")
	rewardPad.PaddingLeft = UDim.new(0.04, 0)
	rewardPad.PaddingRight = UDim.new(0.04, 0)
	rewardPad.Parent = rewardRow

	local rewardTitle = Instance.new("TextLabel")
	rewardTitle.Size = UDim2.fromScale(0.55, 1)
	rewardTitle.BackgroundTransparency = 1
	rewardTitle.Font = Enum.Font.GothamBold
	rewardTitle.Text = "Recompensa"
	rewardTitle.TextColor3 = Color3.fromRGB(224, 228, 255)
	rewardTitle.TextScaled = true
	rewardTitle.TextXAlignment = Enum.TextXAlignment.Left
	rewardTitle.Parent = rewardRow

	local rewardValue = Instance.new("TextLabel")
	rewardValue.Position = UDim2.fromScale(0.56, 0)
	rewardValue.Size = UDim2.fromScale(0.44, 1)
	rewardValue.BackgroundTransparency = 1
	rewardValue.Font = Enum.Font.GothamBlack
	rewardValue.Text = "+5 Gemas"
	rewardValue.TextColor3 = Color3.fromRGB(115, 226, 255)
	rewardValue.TextScaled = true
	rewardValue.TextXAlignment = Enum.TextXAlignment.Right
	rewardValue.Parent = rewardRow
	gemRewardLabel = rewardValue

	local summary = Instance.new("TextLabel")
	summary.Name = "SummaryNotice"
	summary.Position = UDim2.fromScale(0, layout.SummaryPosYScale)
	summary.Size = UDim2.fromScale(1, layout.SummaryHeightScale)
	summary.BackgroundTransparency = 1
	summary.Font = Enum.Font.GothamMedium
	summary.Text = "Zera: Moedas e Áreas | Fica: Todos os Pets e Gemas"
	summary.TextColor3 = Color3.fromRGB(255, 212, 138)
	summary.TextScaled = true
	summary.TextWrapped = true
	summary.Parent = modal

	local summaryConstraint = Instance.new("UITextSizeConstraint")
	summaryConstraint.MaxTextSize = layout.SummaryMaxTextSize
	summaryConstraint.MinTextSize = layout.SummaryMinTextSize
	summaryConstraint.Parent = summary

	local s1 = Instance.new("Frame")
	s1.Name = "StepOnePanel"
	s1.Position = UDim2.fromScale(0, layout.StepOnePosYScale)
	s1.Size = UDim2.fromScale(1, layout.StepOneHeightScale)
	s1.BackgroundTransparency = 1
	s1.Visible = true
	s1.Parent = modal
	stepOnePanel = s1

	local startBtn = Instance.new("TextButton")
	startBtn.Name = "StartRebirthButton"
	startBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	startBtn.Position = UDim2.fromScale(0.5, 0.5)
	startBtn.Size = UDim2.fromScale(0.76, 0.88)
	startBtn.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
	startBtn.Font = Enum.Font.GothamBlack
	startBtn.Text = "Fazer Rebirth!"
	startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	startBtn.TextScaled = true
	startBtn.Parent = s1
	startRebirthButton = startBtn
	addCorner(startBtn, UDim.new(0, 12))
	addStroke(startBtn, Color3.fromRGB(255, 255, 255), 1.5, 0.55)

	local startConstraint = Instance.new("UISizeConstraint")
	startConstraint.MinSize = Vector2.new(180, 52)
	startConstraint.MaxSize = Vector2.new(380, 72)
	startConstraint.Parent = startBtn

	local s2 = Instance.new("Frame")
	s2.Name = "StepTwoPanel"
	s2.Position = UDim2.fromScale(0, layout.StepTwoPosYScale)
	s2.Size = UDim2.fromScale(1, layout.StepTwoHeightScale)
	s2.BackgroundColor3 = Color3.fromRGB(45, 28, 66)
	s2.BorderSizePixel = 0
	s2.Visible = false
	s2.Parent = modal
	stepTwoPanel = s2
	addCorner(s2, UDim.new(0, 12))
	addStroke(s2, Color3.fromRGB(255, 198, 92), 1.5, 0.2)

	local confirmTitle = Instance.new("TextLabel")
	confirmTitle.Name = "ConfirmQuestion"
	confirmTitle.Position = UDim2.fromScale(0.03, layout.StepTwoQuestionPosYScale)
	confirmTitle.Size = UDim2.fromScale(0.94, layout.StepTwoQuestionHeightScale)
	confirmTitle.BackgroundTransparency = 1
	confirmTitle.Font = Enum.Font.GothamBlack
	confirmTitle.Text = "Confirmar Rebirth?"
	confirmTitle.TextColor3 = Color3.fromRGB(255, 232, 138)
	confirmTitle.TextScaled = true
	confirmTitle.Parent = s2

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Name = "CancelButton"
	cancelBtn.Position = UDim2.fromScale(0.04, layout.StepTwoButtonPosYScale)
	cancelBtn.Size = UDim2.fromScale(0.44, layout.StepTwoButtonHeightScale)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(110, 118, 140)
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.Text = "Cancelar"
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.TextScaled = true
	cancelBtn.Parent = s2
	cancelButton = cancelBtn
	addCorner(cancelBtn, UDim.new(0, 10))

	local cancelConstraint = Instance.new("UISizeConstraint")
	cancelConstraint.MinSize = Vector2.new(124, layout.StepTwoButtonMinHeight)
	cancelConstraint.MaxSize = Vector2.new(220, 68)
	cancelConstraint.Parent = cancelBtn

	local confBtn = Instance.new("TextButton")
	confBtn.Name = "ConfirmButton"
	confBtn.AnchorPoint = Vector2.new(1, 0)
	confBtn.Position = UDim2.fromScale(0.96, layout.StepTwoButtonPosYScale)
	confBtn.Size = UDim2.fromScale(0.44, layout.StepTwoButtonHeightScale)
	confBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
	confBtn.Font = Enum.Font.GothamBlack
	confBtn.Text = "Confirmar!"
	confBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confBtn.TextScaled = true
	confBtn.Parent = s2
	confirmButton = confBtn
	addCorner(confBtn, UDim.new(0, 10))

	local confConstraint = Instance.new("UISizeConstraint")
	confConstraint.MinSize = Vector2.new(124, layout.StepTwoButtonMinHeight)
	confConstraint.MaxSize = Vector2.new(220, 68)
	confConstraint.Parent = confBtn

	table.insert(
		connections,
		toggle.Activated:Connect(function()
			if modalFrame then
				RebirthUI.SetModalOpen(not modalFrame.Visible)
			end
		end)
	)

	table.insert(
		connections,
		closeBtn.Activated:Connect(function()
			RebirthUI.SetModalOpen(false)
		end)
	)

	table.insert(
		connections,
		startBtn.Activated:Connect(function()
			if latestState.IsBusy then
				return
			end
			local cost = RebirthHelpers.computeCost(latestState.Rebirths, GameConfig)
			local progress = RebirthHelpers.computeProgress(latestState.Coins, cost)
			if not progress.CanRebirth then
				local missing = RebirthHelpers.formatShortNumber(progress.MissingCoins)
				RebirthUI.ShowToast(`Faltam {missing} moedas para fazer Rebirth!`, true)
				return
			end
			setConfirmationStep(true)
		end)
	)

	table.insert(
		connections,
		cancelBtn.Activated:Connect(function()
			if not latestState.IsBusy then
				setConfirmationStep(false)
			end
		end)
	)

	table.insert(
		connections,
		confBtn.Activated:Connect(function()
			if latestState.IsBusy then
				return
			end
			if confirmCallback then
				confirmCallback()
			end
		end)
	)
end

local function disconnectList(list: { RBXScriptConnection })
	for _, conn in list do
		conn:Disconnect()
	end
	table.clear(list)
end

local function tryConnectSignal(target: any, signalName: string, handler: (...any) -> ()): RBXScriptConnection?
	local ok, conn = pcall(function()
		return target[signalName]:Connect(handler)
	end)
	if ok and conn then
		return conn :: RBXScriptConnection
	end
	return nil
end

local function disconnectPetsModalWatch()
	disconnectList(petsModalWatchConnections)
	watchedPetsModal = nil
end

local function disconnectPetGuiWatch()
	disconnectList(petGuiWatchConnections)
	watchedPetGui = nil
	disconnectPetsModalWatch()
end

local function disconnectAllMutualExclusivityWatchers()
	disconnectList(playerGuiWatchConnections)
	disconnectPetGuiWatch()
end

local function isPetGuiEnabled(petGui: Instance?): boolean
	if petGui and petGui:IsA("ScreenGui") then
		return petGui.Enabled
	end
	return true
end

local function closeRebirthIfPetsModalOpen()
	if
		modalFrame
		and modalFrame.Visible
		and watchedPetsModal
		and watchedPetsModal.Visible
		and isPetGuiEnabled(watchedPetGui)
	then
		RebirthUI.SetModalOpen(false)
	end
end

local function clearGuiResources()
	if isCleaningUp then
		return
	end
	isCleaningUp = true

	disconnectAllMutualExclusivityWatchers()
	disconnectList(rebirthGuiLifecycleConnections)

	if currentCameraConnection then
		currentCameraConnection:Disconnect()
		currentCameraConnection = nil
	end
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	disconnectList(connections)
	table.clear(uiScales)

	local oldGui = rebirthGui
	rebirthGui = nil
	toggleButton = nil
	toggleBadge = nil
	modalFrame = nil
	progressFill = nil
	progressTextLabel = nil
	currentRebirthsLabel = nil
	nextRebirthsLabel = nil
	currentMultiplierLabel = nil
	nextMultiplierLabel = nil
	gemRewardLabel = nil
	stepOnePanel = nil
	stepTwoPanel = nil
	startRebirthButton = nil
	confirmButton = nil
	cancelButton = nil

	if oldGui and oldGui.Parent then
		oldGui:Destroy()
	end

	isCleaningUp = false
end

local function bindPetsModal(modal: Instance)
	if not modal:IsA("GuiObject") then
		return
	end
	if watchedPetsModal == modal then
		closeRebirthIfPetsModalOpen()
		return
	end

	disconnectPetsModalWatch()
	watchedPetsModal = modal

	table.insert(
		petsModalWatchConnections,
		modal:GetPropertyChangedSignal("Visible"):Connect(function()
			closeRebirthIfPetsModalOpen()
		end)
	)

	local destroyConn = tryConnectSignal(modal, "Destroying", function()
		if watchedPetsModal == modal then
			disconnectPetsModalWatch()
		end
	end)
	if destroyConn then
		table.insert(petsModalWatchConnections, destroyConn)
	end

	local ancestryConn = tryConnectSignal(modal, "AncestryChanged", function(_: Instance, newParent: Instance?)
		if
			watchedPetsModal == modal and (not newParent or (watchedPetGui and not modal:IsDescendantOf(watchedPetGui)))
		then
			disconnectPetsModalWatch()
		end
	end)
	if ancestryConn then
		table.insert(petsModalWatchConnections, ancestryConn)
	end

	closeRebirthIfPetsModalOpen()
end

local function bindPetInventoryGui(petGui: Instance)
	if watchedPetGui == petGui then
		local existingModal = petGui:FindFirstChild("PetsModal") or petGui:FindFirstChild("PetsModal", true)
		if existingModal then
			bindPetsModal(existingModal)
		end
		return
	end

	disconnectPetGuiWatch()
	watchedPetGui = petGui

	if petGui:IsA("ScreenGui") then
		table.insert(
			petGuiWatchConnections,
			petGui:GetPropertyChangedSignal("Enabled"):Connect(function()
				closeRebirthIfPetsModalOpen()
			end)
		)
	end

	table.insert(
		petGuiWatchConnections,
		petGui.DescendantAdded:Connect(function(descendant: Instance)
			if descendant.Name == "PetsModal" then
				bindPetsModal(descendant)
			end
		end)
	)

	table.insert(
		petGuiWatchConnections,
		petGui.ChildRemoved:Connect(function(child: Instance)
			if watchedPetsModal and (child == watchedPetsModal or watchedPetsModal:IsDescendantOf(child)) then
				disconnectPetsModalWatch()
			end
		end)
	)

	local destroyConn = tryConnectSignal(petGui, "Destroying", function()
		if watchedPetGui == petGui then
			disconnectPetGuiWatch()
		end
	end)
	if destroyConn then
		table.insert(petGuiWatchConnections, destroyConn)
	end

	local existingModal = petGui:FindFirstChild("PetsModal") or petGui:FindFirstChild("PetsModal", true)
	if existingModal then
		bindPetsModal(existingModal)
	end
end

local function watchPetInventoryModal(playerGui: Instance)
	disconnectAllMutualExclusivityWatchers()

	local existingPetGui = playerGui:FindFirstChild("PetInventoryGui")
	if existingPetGui then
		bindPetInventoryGui(existingPetGui)
	end

	table.insert(
		playerGuiWatchConnections,
		playerGui.ChildAdded:Connect(function(child: Instance)
			if child.Name == "PetInventoryGui" then
				bindPetInventoryGui(child)
			elseif child.Name == "RebirthGui" and child ~= rebirthGui then
				clearGuiResources()
			end
		end)
	)

	table.insert(
		playerGuiWatchConnections,
		playerGui.ChildRemoved:Connect(function(child: Instance)
			if child == rebirthGui then
				clearGuiResources()
			elseif child == watchedPetGui then
				disconnectPetGuiWatch()
			end
		end)
	)

	table.insert(
		playerGuiWatchConnections,
		playerGui.DescendantAdded:Connect(function(descendant: Instance)
			if descendant.Name == "PetInventoryGui" and descendant.Parent == playerGui then
				bindPetInventoryGui(descendant)
			elseif descendant.Name == "PetsModal" then
				local petGui = playerGui:FindFirstChild("PetInventoryGui")
				if petGui and descendant:IsDescendantOf(petGui) then
					bindPetInventoryGui(petGui)
				end
			end
		end)
	)
end

local function bindRebirthGuiLifecycle(gui: ScreenGui, playerGui: Instance)
	disconnectList(rebirthGuiLifecycleConnections)

	local destroyConn = tryConnectSignal(gui, "Destroying", function()
		if rebirthGui == gui then
			clearGuiResources()
		end
	end)
	if destroyConn then
		table.insert(rebirthGuiLifecycleConnections, destroyConn)
	end

	local ancestryConn = tryConnectSignal(gui, "AncestryChanged", function(_: Instance, newParent: Instance?)
		if rebirthGui == gui and newParent ~= playerGui then
			clearGuiResources()
		end
	end)
	if ancestryConn then
		table.insert(rebirthGuiLifecycleConnections, ancestryConn)
	end
end

function RebirthUI.Init(onConfirmRebirth: () -> ())
	-- Init sem yield: apenas registra o callback, sem esperar PlayerGui ou criar instâncias.
	confirmCallback = onConfirmRebirth
end

function RebirthUI.Mount()
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local playerGui = (
		player:FindFirstChildOfClass("PlayerGui")
		or player:FindFirstChild("PlayerGui")
		or player:WaitForChild("PlayerGui")
	) :: PlayerGui

	if rebirthGui and rebirthGui.Parent == playerGui then
		bindCameraViewport()
		renderView()
		return
	end

	clearGuiResources()
	createRebirthGui(playerGui)

	if rebirthGui then
		bindRebirthGuiLifecycle(rebirthGui, playerGui)
	end
	watchPetInventoryModal(playerGui)

	currentCameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCameraViewport)
	bindCameraViewport()
	renderView()
end

function RebirthUI.SetState(state: RebirthViewState)
	latestState = state
	renderView()
end

function RebirthUI.SetModalOpen(open: boolean)
	if not modalFrame then
		return
	end
	if open then
		collapseOtherMenus()
		setConfirmationStep(latestState.IsBusy)
		renderView()
	else
		setConfirmationStep(false)
	end
	modalFrame.Visible = open
end

function RebirthUI.ResetConfirmation()
	setConfirmationStep(false)
end

function RebirthUI.ShowToast(message: string, isError: boolean?)
	HudController.Toast(message, if isError then "error" else "reward")
end

function RebirthUI.Destroy()
	clearGuiResources()
	confirmCallback = nil
end

return RebirthUI
