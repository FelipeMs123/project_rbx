--!strict
-- EggUI.luau (StarterPlayerScripts.Client.UI.Eggs.EggUI)
-- Dono: Squad B. Interface mobile-first da compra e animação de chocar ovos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local PetsConfig = require(Shared.Config.Pets)
local EggHelpers = require(script.Parent.EggHelpers)

local MIN_UI_SCALE = 0.85
local MAX_UI_SCALE = 1.25
local AUTO_CLOSE_SECONDS = 2.2
local TOAST_DURATION_SECONDS = 3.0

local EggUI = {}

local eggsGui: ScreenGui? = nil
local hatchGui: ScreenGui? = nil
local promptPanel: Frame? = nil
local promptTitleLabel: TextLabel? = nil
local priceLabel: TextLabel? = nil
local areaBadgeLabel: TextLabel? = nil
local inventoryLabel: TextLabel? = nil
local chancesListFrame: ScrollingFrame? = nil
local buyButton: TextButton? = nil
local toastFrame: Frame? = nil
local toastLabel: TextLabel? = nil

local hatchOverlay: Frame? = nil
local hatchCard: Frame? = nil
local hatchEggBody: Frame? = nil
local hatchFlashFrame: Frame? = nil
local hatchRevealGroup: Frame? = nil
local hatchRarityBadge: TextLabel? = nil
local hatchPetNameLabel: TextLabel? = nil
local hatchDamageLabel: TextLabel? = nil

local uiScales: { UIScale } = {}
local connections: { RBXScriptConnection } = {}
local currentCameraConnection: RBXScriptConnection? = nil
local cameraConnection: RBXScriptConnection? = nil
local activeTweens: { Tween } = {}

local currentEggId: string? = nil
local purchaseCallback: ((string) -> ())? = nil
local toastToken = 0
local hatchToken = 0
local hatchRevealed = false
local pendingRevealPet: { Name: string, Rarity: string, Multiplier: number }? = nil

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

local function formatNumberText(value: number): string
	if value == math.floor(value) then
		return tostring(value)
	end
	local text = string.format("%.1f", value)
	text = string.gsub(text, "%.0$", "")
	return text
end

local function cancelActiveTweens()
	for _, tween in activeTweens do
		tween:Cancel()
	end
	table.clear(activeTweens)
end

local function trackTween(instance: Instance, info: TweenInfo, props: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, props)
	table.insert(activeTweens, tween)
	tween:Play()
	return tween
end

local function applyRevealContent(petInfo: { Name: string, Rarity: string, Multiplier: number })
	local rarityInfo = EggHelpers.getRarityInfo(petInfo.Rarity)
	local rarityColor = Color3.fromRGB(rarityInfo.R, rarityInfo.G, rarityInfo.B)

	if hatchRarityBadge then
		hatchRarityBadge.Text = string.upper(rarityInfo.Name)
		hatchRarityBadge.BackgroundColor3 = rarityColor
	end
	if hatchPetNameLabel then
		hatchPetNameLabel.Text = petInfo.Name
	end
	if hatchDamageLabel then
		hatchDamageLabel.Text = `+{formatNumberText(petInfo.Multiplier)} Dano`
	end
	if hatchCard then
		local stroke = hatchCard:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = rarityColor
		end
	end
end

local function finishHatchReveal(token: number)
	if token ~= hatchToken or hatchRevealed then
		return
	end
	hatchRevealed = true
	cancelActiveTweens()

	if hatchEggBody then
		hatchEggBody.Visible = false
		hatchEggBody.Rotation = 0
		hatchEggBody.Size = UDim2.fromScale(0.36, 0.44)
	end
	if hatchFlashFrame then
		hatchFlashFrame.BackgroundTransparency = 1
	end
	if pendingRevealPet then
		applyRevealContent(pendingRevealPet)
	end
	if hatchRevealGroup then
		hatchRevealGroup.Visible = true
	end
	if hatchCard then
		hatchCard.Size = UDim2.fromScale(0.34, 0.34)
		trackTween(
			hatchCard,
			TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(0.42, 0.42) }
		)
	end

	task.delay(AUTO_CLOSE_SECONDS, function()
		if token == hatchToken then
			EggUI.HideHatchOverlay()
		end
	end)
end

local function clearChancesList()
	if not chancesListFrame then
		return
	end
	for _, child in chancesListFrame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function populateChancesList(eggDef: EggHelpers.EggDefLike)
	if not chancesListFrame then
		return
	end
	clearChancesList()

	local entries = EggHelpers.buildPetChances(eggDef, PetsConfig :: any)
	for index, entry in entries do
		local rarityInfo = EggHelpers.getRarityInfo(entry.Rarity)
		local rarityColor = Color3.fromRGB(rarityInfo.R, rarityInfo.G, rarityInfo.B)

		local row = Instance.new("Frame")
		row.Name = `PetRow_{entry.PetId}`
		row.LayoutOrder = index
		row.Size = UDim2.fromScale(1, 0.30)
		row.BackgroundColor3 = Color3.fromRGB(43, 35, 68)
		row.BorderSizePixel = 0
		row.Parent = chancesListFrame
		addCorner(row, UDim.new(0, 8))

		local rowSize = Instance.new("UISizeConstraint")
		rowSize.MinSize = Vector2.new(0, 32)
		rowSize.Parent = row

		local rowPadding = Instance.new("UIPadding")
		rowPadding.PaddingLeft = UDim.new(0.03, 0)
		rowPadding.PaddingRight = UDim.new(0.03, 0)
		rowPadding.Parent = row

		local petName = Instance.new("TextLabel")
		petName.Name = "PetName"
		petName.BackgroundTransparency = 1
		petName.Position = UDim2.fromScale(0, 0)
		petName.Size = UDim2.fromScale(0.46, 1)
		petName.Font = Enum.Font.GothamBold
		petName.Text = entry.Name
		petName.TextColor3 = Color3.fromRGB(255, 255, 255)
		petName.TextScaled = true
		petName.TextXAlignment = Enum.TextXAlignment.Left
		petName.Parent = row

		local nameConstraint = Instance.new("UITextSizeConstraint")
		nameConstraint.MaxTextSize = 16
		nameConstraint.MinTextSize = 10
		nameConstraint.Parent = petName

		local rarityBadge = Instance.new("TextLabel")
		rarityBadge.Name = "RarityBadge"
		rarityBadge.AnchorPoint = Vector2.new(0, 0.5)
		rarityBadge.Position = UDim2.fromScale(0.47, 0.5)
		rarityBadge.Size = UDim2.fromScale(0.20, 0.72)
		rarityBadge.BackgroundColor3 = rarityColor
		rarityBadge.Font = Enum.Font.GothamBold
		rarityBadge.Text = rarityInfo.Name
		rarityBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
		rarityBadge.TextScaled = true
		rarityBadge.Parent = row
		addCorner(rarityBadge, UDim.new(0, 6))

		local rarityTextConstraint = Instance.new("UITextSizeConstraint")
		rarityTextConstraint.MaxTextSize = 13
		rarityTextConstraint.MinTextSize = 9
		rarityTextConstraint.Parent = rarityBadge

		local dmgLabel = Instance.new("TextLabel")
		dmgLabel.Name = "DamageLabel"
		dmgLabel.BackgroundTransparency = 1
		dmgLabel.Position = UDim2.fromScale(0.68, 0)
		dmgLabel.Size = UDim2.fromScale(0.18, 1)
		dmgLabel.Font = Enum.Font.GothamMedium
		dmgLabel.Text = `+{formatNumberText(entry.Multiplier)} Dano`
		dmgLabel.TextColor3 = Color3.fromRGB(255, 214, 102)
		dmgLabel.TextScaled = true
		dmgLabel.TextXAlignment = Enum.TextXAlignment.Right
		dmgLabel.Parent = row

		local dmgConstraint = Instance.new("UITextSizeConstraint")
		dmgConstraint.MaxTextSize = 14
		dmgConstraint.MinTextSize = 9
		dmgConstraint.Parent = dmgLabel

		local chanceText = Instance.new("TextLabel")
		chanceText.Name = "ChanceLabel"
		chanceText.BackgroundTransparency = 1
		chanceText.Position = UDim2.fromScale(0.87, 0)
		chanceText.Size = UDim2.fromScale(0.13, 1)
		chanceText.Font = Enum.Font.GothamBold
		chanceText.Text = `{formatNumberText(entry.ChancePercent)}%`
		chanceText.TextColor3 = Color3.fromRGB(164, 244, 207)
		chanceText.TextScaled = true
		chanceText.TextXAlignment = Enum.TextXAlignment.Right
		chanceText.Parent = row

		local chanceConstraint = Instance.new("UITextSizeConstraint")
		chanceConstraint.MaxTextSize = 15
		chanceConstraint.MinTextSize = 10
		chanceConstraint.Parent = chanceText
	end
end

local function renderPrompt(
	eggId: string,
	eggDef: EggHelpers.EggDefLike,
	data: EggHelpers.PlayerDataLike?,
	areaName: string,
	isBusy: boolean
)
	if not promptTitleLabel or not priceLabel or not areaBadgeLabel or not inventoryLabel or not buyButton then
		return
	end

	local currencyName = if eggDef.Currency == "Gems" then "Gemas" else "Moedas"
	promptTitleLabel.Text = eggDef.Name
	priceLabel.Text = `{EggHelpers.formatShortNumber(eggDef.Price)} {currencyName}`

	local unlocked = EggHelpers.isAreaUnlocked(data, eggDef.Area)
	if unlocked then
		areaBadgeLabel.Text = areaName
		areaBadgeLabel.BackgroundColor3 = Color3.fromRGB(56, 161, 105)
	else
		areaBadgeLabel.Text = `Bloqueada: {areaName}`
		areaBadgeLabel.BackgroundColor3 = Color3.fromRGB(214, 78, 78)
	end

	local invCount = if data then EggHelpers.countInventory(data.Inventory) else 0
	inventoryLabel.Text = `{invCount}/{GameConfig.MaxInventory} Pets`
	if invCount >= GameConfig.MaxInventory then
		inventoryLabel.TextColor3 = Color3.fromRGB(255, 135, 135)
	else
		inventoryLabel.TextColor3 = Color3.fromRGB(216, 224, 255)
	end

	local canBuy, errCode = EggHelpers.canPurchaseEgg(data, eggDef, GameConfig.MaxInventory, eggId)
	if isBusy then
		buyButton.Text = "Comprando..."
		buyButton.BackgroundColor3 = Color3.fromRGB(122, 130, 150)
	elseif canBuy then
		buyButton.Text = "Comprar Ovo"
		buyButton.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
	elseif errCode == "AREA_LOCKED" then
		buyButton.Text = "Área Bloqueada"
		buyButton.BackgroundColor3 = Color3.fromRGB(184, 86, 86)
	elseif errCode == "INVENTORY_FULL" then
		buyButton.Text = "Mochila Cheia"
		buyButton.BackgroundColor3 = Color3.fromRGB(196, 114, 54)
	else
		buyButton.Text = "Comprar Ovo"
		buyButton.BackgroundColor3 = Color3.fromRGB(188, 124, 62)
	end
end

local function createEggsGui(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "EggsGui"
	gui.DisplayOrder = 6
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	eggsGui = gui

	local panel = Instance.new("Frame")
	panel.Name = "EggPromptPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.fromScale(0.5, 0.96)
	panel.Size = UDim2.fromScale(0.46, 0.34)
	panel.BackgroundColor3 = Color3.fromRGB(30, 23, 51)
	panel.BackgroundTransparency = 0.06
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.Visible = false
	panel.Parent = gui
	promptPanel = panel
	attachResponsiveScale(panel)
	addCorner(panel, UDim.new(0, 16))
	addStroke(panel, Color3.fromRGB(255, 168, 226), 2, 0.15)

	local panelSizeConstraint = Instance.new("UISizeConstraint")
	panelSizeConstraint.MinSize = Vector2.new(310, 220)
	panelSizeConstraint.MaxSize = Vector2.new(580, 350)
	panelSizeConstraint.Parent = panel

	local panelPadding = Instance.new("UIPadding")
	panelPadding.PaddingTop = UDim.new(0.05, 0)
	panelPadding.PaddingBottom = UDim.new(0.05, 0)
	panelPadding.PaddingLeft = UDim.new(0.04, 0)
	panelPadding.PaddingRight = UDim.new(0.04, 0)
	panelPadding.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromScale(0, 0)
	header.Size = UDim2.fromScale(1, 0.22)
	header.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0, 0)
	title.Size = UDim2.fromScale(0.58, 0.56)
	title.Font = Enum.Font.GothamBlack
	title.Text = "Ovo de Doce"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header
	promptTitleLabel = title

	local titleConstraint = Instance.new("UITextSizeConstraint")
	titleConstraint.MaxTextSize = 24
	titleConstraint.MinTextSize = 14
	titleConstraint.Parent = title

	local pricePill = Instance.new("TextLabel")
	pricePill.Name = "PriceLabel"
	pricePill.AnchorPoint = Vector2.new(1, 0)
	pricePill.Position = UDim2.fromScale(1, 0)
	pricePill.Size = UDim2.fromScale(0.40, 0.54)
	pricePill.BackgroundColor3 = Color3.fromRGB(255, 194, 59)
	pricePill.Font = Enum.Font.GothamBlack
	pricePill.Text = "100 Moedas"
	pricePill.TextColor3 = Color3.fromRGB(48, 28, 10)
	pricePill.TextScaled = true
	pricePill.Parent = header
	priceLabel = pricePill
	addCorner(pricePill, UDim.new(0, 8))

	local priceConstraint = Instance.new("UITextSizeConstraint")
	priceConstraint.MaxTextSize = 16
	priceConstraint.MinTextSize = 11
	priceConstraint.Parent = pricePill

	local areaBadge = Instance.new("TextLabel")
	areaBadge.Name = "AreaBadge"
	areaBadge.Position = UDim2.fromScale(0, 0.62)
	areaBadge.Size = UDim2.fromScale(0.56, 0.38)
	areaBadge.BackgroundColor3 = Color3.fromRGB(56, 161, 105)
	areaBadge.Font = Enum.Font.GothamBold
	areaBadge.Text = "Praça dos Doces"
	areaBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	areaBadge.TextScaled = true
	areaBadge.Parent = header
	areaBadgeLabel = areaBadge
	addCorner(areaBadge, UDim.new(0, 6))

	local areaConstraint = Instance.new("UITextSizeConstraint")
	areaConstraint.MaxTextSize = 13
	areaConstraint.MinTextSize = 9
	areaConstraint.Parent = areaBadge

	local invText = Instance.new("TextLabel")
	invText.Name = "InventoryLabel"
	invText.BackgroundTransparency = 1
	invText.AnchorPoint = Vector2.new(1, 0)
	invText.Position = UDim2.fromScale(1, 0.62)
	invText.Size = UDim2.fromScale(0.40, 0.38)
	invText.Font = Enum.Font.GothamBold
	invText.Text = "0/50 Pets"
	invText.TextColor3 = Color3.fromRGB(216, 224, 255)
	invText.TextScaled = true
	invText.TextXAlignment = Enum.TextXAlignment.Right
	invText.Parent = header
	inventoryLabel = invText

	local invConstraint = Instance.new("UITextSizeConstraint")
	invConstraint.MaxTextSize = 14
	invConstraint.MinTextSize = 10
	invConstraint.Parent = invText

	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "PetChancesList"
	listFrame.Position = UDim2.fromScale(0, 0.25)
	listFrame.Size = UDim2.fromScale(1, 0.44)
	listFrame.BackgroundColor3 = Color3.fromRGB(22, 16, 39)
	listFrame.BackgroundTransparency = 0.2
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 4
	listFrame.CanvasSize = UDim2.fromScale(0, 0)
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = panel
	chancesListFrame = listFrame
	addCorner(listFrame, UDim.new(0, 10))

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0.05, 0)
	listPadding.PaddingBottom = UDim.new(0.05, 0)
	listPadding.PaddingLeft = UDim.new(0.03, 0)
	listPadding.PaddingRight = UDim.new(0.03, 0)
	listPadding.Parent = listFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0.05, 0)
	listLayout.Parent = listFrame

	local button = Instance.new("TextButton")
	button.Name = "BuyEggButton"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.fromScale(0.5, 1)
	button.Size = UDim2.fromScale(0.72, 0.24)
	button.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBlack
	button.Text = "Comprar Ovo"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Parent = panel
	buyButton = button
	addCorner(button, UDim.new(0, 12))
	addStroke(button, Color3.fromRGB(255, 255, 255), 1.5, 0.55)

	local buyConstraint = Instance.new("UISizeConstraint")
	buyConstraint.MinSize = Vector2.new(150, 52)
	buyConstraint.MaxSize = Vector2.new(360, 72)
	buyConstraint.Parent = button

	local buyTextConstraint = Instance.new("UITextSizeConstraint")
	buyTextConstraint.MaxTextSize = 22
	buyTextConstraint.MinTextSize = 13
	buyTextConstraint.Parent = button

	table.insert(
		connections,
		button.Activated:Connect(function()
			if currentEggId and purchaseCallback then
				purchaseCallback(currentEggId)
			end
		end)
	)

	local toast = Instance.new("Frame")
	toast.Name = "EggToastBanner"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.fromScale(0.5, 0.13)
	toast.Size = UDim2.fromScale(0.46, 0.07)
	toast.BackgroundColor3 = Color3.fromRGB(45, 32, 70)
	toast.BorderSizePixel = 0
	toast.Visible = false
	toast.Active = false
	toast.Parent = gui
	toastFrame = toast
	attachResponsiveScale(toast)
	addCorner(toast, UDim.new(0, 12))
	addStroke(toast, Color3.fromRGB(255, 184, 108), 2, 0.1)

	local toastConstraint = Instance.new("UISizeConstraint")
	toastConstraint.MinSize = Vector2.new(260, 44)
	toastConstraint.MaxSize = Vector2.new(540, 66)
	toastConstraint.Parent = toast

	local toastText = Instance.new("TextLabel")
	toastText.Name = "ToastMessage"
	toastText.BackgroundTransparency = 1
	toastText.Position = UDim2.fromScale(0.04, 0.1)
	toastText.Size = UDim2.fromScale(0.92, 0.8)
	toastText.Font = Enum.Font.GothamBold
	toastText.Text = ""
	toastText.TextColor3 = Color3.fromRGB(255, 255, 255)
	toastText.TextScaled = true
	toastText.Parent = toast
	toastLabel = toastText

	local toastTextConstraint = Instance.new("UITextSizeConstraint")
	toastTextConstraint.MaxTextSize = 18
	toastTextConstraint.MinTextSize = 11
	toastTextConstraint.Parent = toastText
end

local function createHatchGui(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "EggHatchGui"
	gui.DisplayOrder = 20
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	hatchGui = gui

	local overlay = Instance.new("Frame")
	overlay.Name = "EggHatchOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(14, 10, 26)
	overlay.BackgroundTransparency = 0.45
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Active = true
	overlay.Parent = gui
	hatchOverlay = overlay

	local flash = Instance.new("Frame")
	flash.Name = "FlashFrame"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 248, 220)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 4
	flash.Active = false
	flash.Parent = overlay
	hatchFlashFrame = flash

	local card = Instance.new("Frame")
	card.Name = "HatchCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.42, 0.42)
	card.BackgroundColor3 = Color3.fromRGB(36, 26, 62)
	card.BorderSizePixel = 0
	card.ZIndex = 2
	card.Parent = overlay
	hatchCard = card
	attachResponsiveScale(card)
	addCorner(card, UDim.new(0, 20))
	addStroke(card, Color3.fromRGB(255, 200, 107), 3, 0)

	local cardConstraint = Instance.new("UISizeConstraint")
	cardConstraint.MinSize = Vector2.new(280, 260)
	cardConstraint.MaxSize = Vector2.new(460, 380)
	cardConstraint.Parent = card

	local tapOverlayBtn = Instance.new("TextButton")
	tapOverlayBtn.Name = "SkipTapButton"
	tapOverlayBtn.Size = UDim2.fromScale(1, 1)
	tapOverlayBtn.BackgroundTransparency = 1
	tapOverlayBtn.Text = ""
	tapOverlayBtn.Modal = false
	tapOverlayBtn.ZIndex = 2
	tapOverlayBtn.Parent = card

	local eggBody = Instance.new("Frame")
	eggBody.Name = "EggVisual"
	eggBody.AnchorPoint = Vector2.new(0.5, 0.5)
	eggBody.Position = UDim2.fromScale(0.5, 0.46)
	eggBody.Size = UDim2.fromScale(0.36, 0.46)
	eggBody.BackgroundColor3 = Color3.fromRGB(255, 152, 208)
	eggBody.BorderSizePixel = 0
	eggBody.ZIndex = 3
	eggBody.Parent = card
	hatchEggBody = eggBody
	addCorner(eggBody, UDim.new(0.5, 0))
	addStroke(eggBody, Color3.fromRGB(255, 255, 255), 3, 0.2)

	local eggRatio = Instance.new("UIAspectRatioConstraint")
	eggRatio.AspectRatio = 0.82
	eggRatio.Parent = eggBody

	local eggHint = Instance.new("TextLabel")
	eggHint.Name = "EggHint"
	eggHint.AnchorPoint = Vector2.new(0.5, 0)
	eggHint.Position = UDim2.fromScale(0.5, 1.08)
	eggHint.Size = UDim2.fromScale(2.0, 0.25)
	eggHint.BackgroundTransparency = 1
	eggHint.Font = Enum.Font.GothamBold
	eggHint.Text = "Chocando..."
	eggHint.TextColor3 = Color3.fromRGB(255, 232, 165)
	eggHint.TextScaled = true
	eggHint.ZIndex = 3
	eggHint.Parent = eggBody

	local revealGroup = Instance.new("Frame")
	revealGroup.Name = "RevealGroup"
	revealGroup.Size = UDim2.fromScale(1, 1)
	revealGroup.BackgroundTransparency = 1
	revealGroup.Visible = false
	revealGroup.ZIndex = 3
	revealGroup.Parent = card
	hatchRevealGroup = revealGroup

	local revealPadding = Instance.new("UIPadding")
	revealPadding.PaddingTop = UDim.new(0.08, 0)
	revealPadding.PaddingBottom = UDim.new(0.08, 0)
	revealPadding.PaddingLeft = UDim.new(0.07, 0)
	revealPadding.PaddingRight = UDim.new(0.07, 0)
	revealPadding.Parent = revealGroup

	local headerText = Instance.new("TextLabel")
	headerText.Name = "NewPetHeader"
	headerText.Size = UDim2.fromScale(1, 0.14)
	headerText.BackgroundTransparency = 1
	headerText.Font = Enum.Font.GothamBlack
	headerText.Text = "Você ganhou um novo Pet!"
	headerText.TextColor3 = Color3.fromRGB(255, 230, 128)
	headerText.TextScaled = true
	headerText.ZIndex = 3
	headerText.Parent = revealGroup

	local rarityBadge = Instance.new("TextLabel")
	rarityBadge.Name = "RarityBadge"
	rarityBadge.AnchorPoint = Vector2.new(0.5, 0)
	rarityBadge.Position = UDim2.fromScale(0.5, 0.19)
	rarityBadge.Size = UDim2.fromScale(0.46, 0.13)
	rarityBadge.BackgroundColor3 = Color3.fromRGB(160, 174, 192)
	rarityBadge.Font = Enum.Font.GothamBlack
	rarityBadge.Text = "COMUM"
	rarityBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	rarityBadge.TextScaled = true
	rarityBadge.ZIndex = 3
	rarityBadge.Parent = revealGroup
	hatchRarityBadge = rarityBadge
	addCorner(rarityBadge, UDim.new(0, 8))

	local petName = Instance.new("TextLabel")
	petName.Name = "PetName"
	petName.AnchorPoint = Vector2.new(0.5, 0)
	petName.Position = UDim2.fromScale(0.5, 0.36)
	petName.Size = UDim2.fromScale(0.96, 0.20)
	petName.BackgroundTransparency = 1
	petName.Font = Enum.Font.GothamBlack
	petName.Text = "Pet"
	petName.TextColor3 = Color3.fromRGB(255, 255, 255)
	petName.TextScaled = true
	petName.ZIndex = 3
	petName.Parent = revealGroup
	hatchPetNameLabel = petName

	local dmgLabel = Instance.new("TextLabel")
	dmgLabel.Name = "DamageBonus"
	dmgLabel.AnchorPoint = Vector2.new(0.5, 0)
	dmgLabel.Position = UDim2.fromScale(0.5, 0.58)
	dmgLabel.Size = UDim2.fromScale(0.70, 0.12)
	dmgLabel.BackgroundTransparency = 1
	dmgLabel.Font = Enum.Font.GothamBold
	dmgLabel.Text = "+1.5 Dano"
	dmgLabel.TextColor3 = Color3.fromRGB(142, 247, 179)
	dmgLabel.TextScaled = true
	dmgLabel.ZIndex = 3
	dmgLabel.Parent = revealGroup
	hatchDamageLabel = dmgLabel

	local contBtn = Instance.new("TextButton")
	contBtn.Name = "ContinueButton"
	contBtn.AnchorPoint = Vector2.new(0.5, 1)
	contBtn.Position = UDim2.fromScale(0.5, 1)
	contBtn.Size = UDim2.fromScale(0.64, 0.21)
	contBtn.BackgroundColor3 = Color3.fromRGB(68, 168, 255)
	contBtn.Font = Enum.Font.GothamBlack
	contBtn.Text = "Continuar"
	contBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	contBtn.TextScaled = true
	contBtn.Modal = false
	contBtn.ZIndex = 4
	contBtn.Parent = revealGroup
	addCorner(contBtn, UDim.new(0, 12))

	local contConstraint = Instance.new("UISizeConstraint")
	contConstraint.MinSize = Vector2.new(150, 52)
	contConstraint.MaxSize = Vector2.new(300, 68)
	contConstraint.Parent = contBtn

	local contTextConstraint = Instance.new("UITextSizeConstraint")
	contTextConstraint.MaxTextSize = 20
	contTextConstraint.MinTextSize = 13
	contTextConstraint.Parent = contBtn

	table.insert(
		connections,
		tapOverlayBtn.Activated:Connect(function()
			if not hatchRevealed then
				finishHatchReveal(hatchToken)
			else
				EggUI.HideHatchOverlay()
			end
		end)
	)

	table.insert(
		connections,
		contBtn.Activated:Connect(function()
			EggUI.HideHatchOverlay()
		end)
	)
end

local function clearGuiResources()
	hatchToken += 1
	toastToken += 1
	cancelActiveTweens()

	if currentCameraConnection then
		currentCameraConnection:Disconnect()
		currentCameraConnection = nil
	end
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(uiScales)

	if eggsGui then
		eggsGui:Destroy()
		eggsGui = nil
	end
	if hatchGui then
		hatchGui:Destroy()
		hatchGui = nil
	end

	promptPanel = nil
	promptTitleLabel = nil
	priceLabel = nil
	areaBadgeLabel = nil
	inventoryLabel = nil
	chancesListFrame = nil
	buyButton = nil
	toastFrame = nil
	toastLabel = nil
	hatchOverlay = nil
	hatchCard = nil
	hatchEggBody = nil
	hatchFlashFrame = nil
	hatchRevealGroup = nil
	hatchRarityBadge = nil
	hatchPetNameLabel = nil
	hatchDamageLabel = nil
end

function EggUI.Init(onPurchase: (string) -> ())
	-- Init sem yield: apenas registra o callback, sem esperar PlayerGui ou criar instâncias.
	purchaseCallback = onPurchase
end

function EggUI.Mount()
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local playerGui = (
		player:FindFirstChildOfClass("PlayerGui")
		or player:FindFirstChild("PlayerGui")
		or player:WaitForChild("PlayerGui")
	) :: PlayerGui

	if eggsGui and eggsGui.Parent == playerGui and hatchGui and hatchGui.Parent == playerGui then
		bindCameraViewport()
		return
	end

	clearGuiResources()
	createEggsGui(playerGui)
	createHatchGui(playerGui)

	currentCameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCameraViewport)
	bindCameraViewport()
end

function EggUI.ShowPrompt(
	eggId: string,
	eggDef: EggHelpers.EggDefLike,
	data: EggHelpers.PlayerDataLike?,
	areaName: string,
	isBusy: boolean
)
	if not promptPanel then
		return
	end
	local changedEgg = currentEggId ~= eggId
	currentEggId = eggId
	if changedEgg or (chancesListFrame and #chancesListFrame:GetChildren() <= 2) then
		populateChancesList(eggDef)
	end
	renderPrompt(eggId, eggDef, data, areaName, isBusy)
	promptPanel.Visible = true
end

function EggUI.UpdatePrompt(
	eggId: string,
	eggDef: EggHelpers.EggDefLike,
	data: EggHelpers.PlayerDataLike?,
	areaName: string,
	isBusy: boolean
)
	if currentEggId ~= eggId then
		return
	end
	renderPrompt(eggId, eggDef, data, areaName, isBusy)
end

function EggUI.HidePrompt()
	currentEggId = nil
	if promptPanel then
		promptPanel.Visible = false
	end
end

function EggUI.IsPromptVisible(): boolean
	return promptPanel ~= nil and promptPanel.Visible
end

function EggUI.ShowToast(message: string, isError: boolean?)
	if not toastFrame or not toastLabel then
		return
	end
	toastToken += 1
	local token = toastToken

	toastLabel.Text = message
	local stroke = toastFrame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if isError then Color3.fromRGB(255, 118, 118) else Color3.fromRGB(110, 231, 183)
	end
	toastFrame.Visible = true

	task.delay(TOAST_DURATION_SECONDS, function()
		if token == toastToken and toastFrame then
			toastFrame.Visible = false
		end
	end)
end

function EggUI.ShowHatchResult(petId: string, petDef: EggHelpers.PetDefLike?)
	if not hatchOverlay or not hatchCard or not hatchEggBody or not hatchRevealGroup or not hatchFlashFrame then
		return
	end

	hatchToken += 1
	local token = hatchToken
	hatchRevealed = false
	cancelActiveTweens()

	local resolvedPet = {
		Name = if petDef then petDef.Name else petId,
		Rarity = if petDef then petDef.Rarity else "Common",
		Multiplier = if petDef then petDef.Multiplier else 0,
	}
	pendingRevealPet = resolvedPet

	hatchOverlay.Visible = true
	hatchRevealGroup.Visible = false
	hatchEggBody.Visible = true
	hatchEggBody.Rotation = 0
	hatchEggBody.Size = UDim2.fromScale(0.36, 0.46)
	hatchFlashFrame.BackgroundTransparency = 1

	hatchCard.Size = UDim2.fromScale(0.32, 0.32)
	trackTween(
		hatchCard,
		TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(0.42, 0.42) }
	)

	task.spawn(function()
		local angles = { -15, 15, -18, 18, 0 }
		for _, angle in angles do
			if token ~= hatchToken or hatchRevealed then
				return
			end
			local shakeTween = trackTween(
				hatchEggBody :: Frame,
				TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ Rotation = angle }
			)
			shakeTween.Completed:Wait()
		end

		if token ~= hatchToken or hatchRevealed then
			return
		end

		local flashIn = trackTween(
			hatchFlashFrame :: Frame,
			TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.1 }
		)
		flashIn.Completed:Wait()

		if token ~= hatchToken or hatchRevealed then
			return
		end

		finishHatchReveal(token)
		if hatchFlashFrame then
			trackTween(
				hatchFlashFrame,
				TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ BackgroundTransparency = 1 }
			)
		end
	end)
end

function EggUI.HideHatchOverlay()
	hatchToken += 1
	hatchRevealed = false
	pendingRevealPet = nil
	cancelActiveTweens()
	if hatchOverlay then
		hatchOverlay.Visible = false
	end
end

function EggUI.Destroy()
	clearGuiResources()
	purchaseCallback = nil
	currentEggId = nil
	pendingRevealPet = nil
	hatchRevealed = false
end

return EggUI
