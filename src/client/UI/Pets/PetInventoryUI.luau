--!strict
-- PetInventoryUI.luau (StarterPlayerScripts.Client.UI.Pets.PetInventoryUI)
-- Dono: Squad B. Interface mobile-first do inventário de pets (botão flutuante, modal, grade e avisos).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ErrorCodes = require(Shared.ErrorCodes)
local FusionConfig = require(Shared.Config.Fusion)
local GameConfig = require(Shared.Config.Game)
local PetsConfig = require(Shared.Config.Pets)
local Inventory = require(Shared.Logic.Inventory)
local Types = require(Shared.Types)

local PetInventoryUI = {}

export type TogglePetCallback = (uuid: string, currentlyEquipped: boolean) -> ()
export type FusePetsCallback = (uuids: { string }) -> ()

export type PetEntry = {
	uuid: string,
	petId: string,
	variant: string?,
	multiplier: number,
	def: Types.PetDef,
	equipped: boolean,
}

local DEFAULT_RARITY_COLOR = Color3.fromRGB(165, 177, 194)
local GOLDEN_COLOR = Color3.fromRGB(255, 215, 70)
local GOLDEN_BG_COLOR = Color3.fromRGB(62, 52, 26)
local GOLDEN_EQUIPPED_BG_COLOR = Color3.fromRGB(54, 62, 38)
local TAB_ACTIVE_COLOR = Color3.fromRGB(255, 107, 129)
local TAB_FUSION_ACTIVE_COLOR = Color3.fromRGB(245, 180, 40)
local TAB_INACTIVE_COLOR = Color3.fromRGB(34, 39, 54)

local RARITY_COLORS: { [string]: Color3 } = {
	Common = DEFAULT_RARITY_COLOR,
	Uncommon = Color3.fromRGB(75, 207, 115),
	Rare = Color3.fromRGB(69, 170, 242),
	Epic = Color3.fromRGB(165, 94, 234),
	Legendary = Color3.fromRGB(254, 202, 87),
}

local RARITY_LABELS: { [string]: string } = {
	Common = "Comum",
	Uncommon = "Incomum",
	Rare = "Raro",
	Epic = "Épico",
	Legendary = "Lendário",
}

local ERROR_MESSAGES: { [string]: string } = {
	[ErrorCodes.INVALID_ARGS] = "Ops! Algo deu errado com esse pet. Tente de novo!",
	[ErrorCodes.RATE_LIMITED] = "Calma aí! Você está clicando muito rápido!",
	[ErrorCodes.DATA_NOT_LOADED] = "Seus dados ainda estão carregando. Espere um pouquinho!",
	[ErrorCodes.INTERNAL] = "Ops! O servidor teve um soluço. Tente novamente!",
	[ErrorCodes.NOT_ENOUGH_COINS] = "Você não tem moedas suficientes!",
	[ErrorCodes.NOT_ENOUGH_GEMS] = "Você não tem gemas suficientes!",
	[ErrorCodes.NOT_OWNED] = "Você não tem esse pet na sua mochila!",
	[ErrorCodes.ALREADY_EQUIPPED] = "Esse pet já está equipado!",
	[ErrorCodes.NOT_EQUIPPED] = "Esse pet não está equipado no momento!",
	[ErrorCodes.MAX_EQUIPPED] = `Você só pode equipar até {GameConfig.MaxEquipped} pets ao mesmo tempo!`,
	[ErrorCodes.INVENTORY_FULL] = `Sua mochila está cheia ({GameConfig.MaxInventory}/{GameConfig.MaxInventory} pets)!`,
	[ErrorCodes.AREA_LOCKED] = "Essa área ainda está trancada!",
	[ErrorCodes.ALREADY_UNLOCKED] = "Você já liberou essa área!",
	[ErrorCodes.FUSE_INVALID] = "Selecione 5 pets normais iguais e não equipados para fundir!",
	[ErrorCodes.UNKNOWN_ITEM] = "Esse pet não foi reconhecido pelo jogo!",
	[ErrorCodes.TOO_FAR] = "Chegue mais perto para fazer isso!",
	[ErrorCodes.NOT_IMPLEMENTED] = "Essa função estará disponível em breve!",
}

local MIN_TOUCH_PX = 44
local SAFE_TOUCH_PX = 45
local HEADER_HEIGHT_PX = 58
local STATS_HEIGHT_PX = 40
local TABS_HEIGHT_PX = 44
local SECTION_GAP_PX = 6
local TABS_TOP_OFFSET_PX = HEADER_HEIGHT_PX + SECTION_GAP_PX + STATS_HEIGHT_PX + SECTION_GAP_PX
local CONTENT_TOP_OFFSET_PX = TABS_TOP_OFFSET_PX + TABS_HEIGHT_PX + SECTION_GAP_PX
local GRID_PADDING_PX = 10
local GRID_GAP_PX = 10
local SCROLLBAR_THICKNESS_PX = 8

local screenGui: ScreenGui? = nil
local uiScale: UIScale? = nil
local modalFrame: Frame? = nil
local bonusLabel: TextLabel? = nil
local equippedCountLabel: TextLabel? = nil
local inventoryCountLabel: TextLabel? = nil
local toastLabel: TextLabel? = nil
local gridFrame: ScrollingFrame? = nil
local gridLayoutRef: UIGridLayout? = nil
local emptyLabel: TextLabel? = nil
local fusionPanel: Frame? = nil
local fusionListFrame: ScrollingFrame? = nil
local fusionEmptyLabel: TextLabel? = nil
local fusionGemsLabel: TextLabel? = nil
local inventoryTabBtn: TextButton? = nil
local fusionTabBtn: TextButton? = nil
local inventoryTabConstraint: UISizeConstraint? = nil
local fusionTabConstraint: UISizeConstraint? = nil
local toggleButton: TextButton? = nil
local openBtnConstraint: UISizeConstraint? = nil
local closeBtnConstraint: UISizeConstraint? = nil

local connections: { RBXScriptConnection } = {}
local cardConnections: { RBXScriptConnection } = {}
local fusionConnections: { RBXScriptConnection } = {}
local onToggleCallback: TogglePetCallback? = nil
local onFuseCallback: FusePetsCallback? = nil
local pendingUuids: { [string]: boolean } = {}
local fusePending = false
local activeTab: "inventory" | "fusion" = "inventory"
local toastToken = 0

local function formatNumber(n: number): string
	if math.abs(n - math.round(n)) < 0.001 then
		return tostring(math.round(n))
	end
	return string.format("%.1f", n)
end

local function getMinTouchLocal(): number
	local scale = if uiScale then math.max(uiScale.Scale, 0.01) else 1
	return math.max(MIN_TOUCH_PX, math.ceil(SAFE_TOUCH_PX / scale))
end

local function updateGridLayout()
	local grid = gridFrame
	local layout = gridLayoutRef
	local scaleInst = uiScale
	if not grid or not layout or not scaleInst then
		return
	end

	local scale = math.max(scaleInst.Scale, 0.01)
	local absWidth = grid.AbsoluteSize.X
	if absWidth <= 0 then
		return
	end

	-- AbsoluteSize já reflete UIScale; divide pela escala para calcular Offset no espaço local do grid
	local unscaledWidth = absWidth / scale
	local usableWidth = math.max(160, unscaledWidth - (GRID_PADDING_PX * 2) - SCROLLBAR_THICKNESS_PX - 4)
	local columns = if usableWidth >= 340 then 3 else 2
	local cellWidth = math.floor((usableWidth - GRID_GAP_PX * (columns - 1)) / columns)
	local minTouch = math.max(MIN_TOUCH_PX, math.ceil(SAFE_TOUCH_PX / scale))
	local cellHeight = math.max(minTouch, math.clamp(math.round(cellWidth * 0.85), 112, 152))

	layout.FillDirectionMaxCells = columns
	layout.CellPadding = UDim2.fromOffset(GRID_GAP_PX, GRID_GAP_PX)
	layout.CellSize = UDim2.fromOffset(cellWidth, cellHeight)
end

local function updateResponsiveScale()
	local scaleInst = uiScale
	if not scaleInst then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local minAxis = math.min(viewport.X, viewport.Y)
	if minAxis <= 0 then
		return
	end
	-- Escala suave para celulares pequenos até telas grandes de PC
	local computed = math.clamp(minAxis / 520, 0.78, 1.15)
	scaleInst.Scale = computed

	-- Compensa UIScale nos MinSize para manter área de toque >= 44 px reais em telas pequenas
	local minTouch = math.max(MIN_TOUCH_PX, math.ceil(SAFE_TOUCH_PX / computed))
	if openBtnConstraint then
		openBtnConstraint.MinSize = Vector2.new(math.max(96, minTouch), minTouch)
	end
	if closeBtnConstraint then
		closeBtnConstraint.MinSize = Vector2.new(minTouch, minTouch)
	end
	if inventoryTabConstraint then
		inventoryTabConstraint.MinSize = Vector2.new(96, minTouch)
	end
	if fusionTabConstraint then
		fusionTabConstraint.MinSize = Vector2.new(96, minTouch)
	end

	updateGridLayout()
end

local function clearCards()
	for _, conn in cardConnections do
		conn:Disconnect()
	end
	table.clear(cardConnections)

	local grid = gridFrame
	if not grid then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function clearFusionCards()
	for _, conn in fusionConnections do
		conn:Disconnect()
	end
	table.clear(fusionConnections)

	local list = fusionListFrame
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local currentEntryCount = 0

local function applyTabVisuals()
	local isInventory = activeTab == "inventory"
	if gridFrame then
		gridFrame.Visible = isInventory
	end
	if emptyLabel then
		emptyLabel.Visible = isInventory and currentEntryCount == 0
	end
	if fusionPanel then
		fusionPanel.Visible = not isInventory
	end
	if inventoryTabBtn then
		inventoryTabBtn.BackgroundColor3 = if isInventory then TAB_ACTIVE_COLOR else TAB_INACTIVE_COLOR
		inventoryTabBtn.TextColor3 = if isInventory
			then Color3.fromRGB(255, 255, 255)
			else Color3.fromRGB(185, 195, 215)
	end
	if fusionTabBtn then
		fusionTabBtn.BackgroundColor3 = if not isInventory then TAB_FUSION_ACTIVE_COLOR else TAB_INACTIVE_COLOR
		fusionTabBtn.TextColor3 = if not isInventory then Color3.fromRGB(24, 27, 38) else GOLDEN_COLOR
	end
end

function PetInventoryUI.TranslateError(errCode: string?): string
	if not errCode then
		return "Não foi possível completar a ação. Tente de novo!"
	end
	return ERROR_MESSAGES[errCode] or "Não foi possível completar a ação. Tente de novo!"
end

function PetInventoryUI.ShowToast(message: string, isError: boolean)
	local label = toastLabel
	if not label then
		return
	end
	toastToken += 1
	local myToken = toastToken

	label.Text = message
	label.BackgroundColor3 = if isError then Color3.fromRGB(235, 77, 75) else Color3.fromRGB(46, 213, 115)
	label.Visible = true

	task.delay(2.8, function()
		if toastToken == myToken and label.Parent then
			label.Visible = false
		end
	end)
end

function PetInventoryUI.SetPending(uuid: string, isPending: boolean)
	if isPending then
		pendingUuids[uuid] = true
	else
		pendingUuids[uuid] = nil
	end

	local grid = gridFrame
	if not grid then
		return
	end
	local card = grid:FindFirstChild(`PetCard_{uuid}`)
	if card and card:IsA("TextButton") then
		card.AutoButtonColor = not isPending
		local actionLabel = card:FindFirstChild("StatusBadge")
		if actionLabel and actionLabel:IsA("TextLabel") and isPending then
			actionLabel.Text = "Aguarde..."
		end
	end
end

function PetInventoryUI.IsPending(uuid: string): boolean
	return pendingUuids[uuid] == true
end

function PetInventoryUI.SetFusePending(isPending: boolean)
	fusePending = isPending
	local list = fusionListFrame
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			local btn = child:FindFirstChild("FuseButton")
			if btn and btn:IsA("TextButton") then
				btn.AutoButtonColor = not isPending
				btn.Text = if isPending then "Fundindo..." else "Fundir"
			end
		end
	end
end

function PetInventoryUI.IsFusePending(): boolean
	return fusePending
end

function PetInventoryUI.IsModalOpen(): boolean
	return modalFrame ~= nil and modalFrame.Visible
end

function PetInventoryUI.BuildSortedEntries(data: Types.PlayerData?): ({ PetEntry }, number, number, number)
	if not data then
		return {}, 0, 0, 0
	end

	local equippedSet: { [string]: boolean } = {}
	for _, uuid in data.Equipped do
		equippedSet[uuid] = true
	end

	local entries: { PetEntry } = {}
	local totalBonus = 0
	local equippedCount = 0
	local inventoryCount = 0

	for uuid, petInstance in data.Inventory do
		inventoryCount += 1
		local def = PetsConfig[petInstance.Id]
		if def then
			local variant = if Inventory.isValidVariant(petInstance.Variant) then petInstance.Variant else nil
			local multiplier = Inventory.petMultiplier(petInstance, PetsConfig :: any, FusionConfig :: any)
			local isEquipped = equippedSet[uuid] == true
			if isEquipped then
				equippedCount += 1
				totalBonus += multiplier
			end
			table.insert(entries, {
				uuid = uuid,
				petId = petInstance.Id,
				variant = variant,
				multiplier = multiplier,
				def = def,
				equipped = isEquipped,
			})
		end
	end

	table.sort(entries, function(a: PetEntry, b: PetEntry): boolean
		if a.equipped ~= b.equipped then
			return a.equipped
		end
		if a.multiplier ~= b.multiplier then
			return a.multiplier > b.multiplier
		end
		local aGolden = a.variant == "Golden"
		local bGolden = b.variant == "Golden"
		if aGolden ~= bGolden then
			return aGolden
		end
		if a.def.Name ~= b.def.Name then
			return a.def.Name < b.def.Name
		end
		return a.uuid < b.uuid
	end)

	return entries, totalBonus, equippedCount, inventoryCount
end

local function createPetCard(entry: PetEntry, parent: ScrollingFrame)
	local rarityColor = RARITY_COLORS[entry.def.Rarity] or DEFAULT_RARITY_COLOR
	local rarityText = RARITY_LABELS[entry.def.Rarity] or "Comum"
	local isGolden = entry.variant == "Golden"
	local isPending = pendingUuids[entry.uuid] == true

	local card = Instance.new("TextButton")
	card.Name = `PetCard_{entry.uuid}`
	card.BackgroundColor3 = if isGolden
		then (if entry.equipped then GOLDEN_EQUIPPED_BG_COLOR else GOLDEN_BG_COLOR)
		elseif entry.equipped then Color3.fromRGB(45, 58, 82)
		else Color3.fromRGB(36, 40, 56)
	card.BorderSizePixel = 0
	card.Text = ""
	card.AutoButtonColor = not isPending

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if entry.equipped or isGolden then 3 else 2
	stroke.Color = if entry.equipped then Color3.fromRGB(46, 213, 115) elseif isGolden then GOLDEN_COLOR else rarityColor
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.Parent = card

	local rarityBadge = Instance.new("TextLabel")
	rarityBadge.Name = "RarityBadge"
	rarityBadge.Size = UDim2.fromScale(1, 0.2)
	rarityBadge.Position = UDim2.fromScale(0, 0)
	rarityBadge.BackgroundColor3 = if isGolden then GOLDEN_COLOR else rarityColor
	rarityBadge.BorderSizePixel = 0
	rarityBadge.Font = Enum.Font.GothamBold
	rarityBadge.Text = if isGolden then `{rarityText} · Dourado` else rarityText
	rarityBadge.TextColor3 = Color3.fromRGB(25, 25, 35)
	rarityBadge.TextScaled = true
	rarityBadge.Parent = card

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 6)
	badgeCorner.Parent = rarityBadge

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PetName"
	nameLabel.Size = UDim2.fromScale(1, 0.34)
	nameLabel.Position = UDim2.fromScale(0, 0.22)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = entry.def.Name
	nameLabel.TextColor3 = if isGolden then Color3.fromRGB(255, 243, 190) else Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = true
	nameLabel.Parent = card

	local multLabel = Instance.new("TextLabel")
	multLabel.Name = "MultiplierLabel"
	multLabel.Size = UDim2.fromScale(1, 0.2)
	multLabel.Position = UDim2.fromScale(0, 0.56)
	multLabel.BackgroundTransparency = 1
	multLabel.Font = Enum.Font.GothamBold
	multLabel.Text = if isGolden
		then `+{formatNumber(entry.multiplier)} Dano (2×)`
		else `+{formatNumber(entry.multiplier)} Dano`
	multLabel.TextColor3 = if isGolden then GOLDEN_COLOR else Color3.fromRGB(255, 221, 89)
	multLabel.TextScaled = true
	multLabel.Parent = card

	local statusBadge = Instance.new("TextLabel")
	statusBadge.Name = "StatusBadge"
	statusBadge.Size = UDim2.fromScale(1, 0.2)
	statusBadge.Position = UDim2.fromScale(0, 0.8)
	statusBadge.BackgroundColor3 = if entry.equipped then Color3.fromRGB(46, 213, 115) else Color3.fromRGB(87, 96, 111)
	statusBadge.BorderSizePixel = 0
	statusBadge.Font = Enum.Font.GothamBold
	statusBadge.Text = if isPending then "Aguarde..." elseif entry.equipped then "EQUIPADO" else "Equipar"
	statusBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusBadge.TextScaled = true
	statusBadge.Parent = card

	local statusCorner = Instance.new("UICorner")
	statusCorner.CornerRadius = UDim.new(0, 6)
	statusCorner.Parent = statusBadge

	local conn = card.Activated:Connect(function()
		if pendingUuids[entry.uuid] then
			return
		end
		if onToggleCallback then
			onToggleCallback(entry.uuid, entry.equipped)
		end
	end)
	table.insert(cardConnections, conn)

	card.Parent = parent
end

local function createFusionCard(
	group: Inventory.FusableGroup,
	playerGems: number,
	layoutOrder: number,
	parent: ScrollingFrame
)
	local rarityKey = group.def.Rarity or "Common"
	local rarityColor = RARITY_COLORS[rarityKey] or DEFAULT_RARITY_COLOR
	local rarityText = RARITY_LABELS[rarityKey] or "Comum"
	local petName = group.def.Name or group.petId
	local baseMult = group.def.Multiplier
	local goldenMult = baseMult * FusionConfig.GoldenMultiplier
	local canAfford = playerGems >= group.gemCost

	local card = Instance.new("Frame")
	card.Name = `FusionCard_{group.petId}`
	card.Size = UDim2.new(1, 0, 0, 88)
	card.BackgroundColor3 = Color3.fromRGB(36, 40, 56)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = if canAfford then GOLDEN_COLOR else rarityColor
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = card

	local info = Instance.new("Frame")
	info.Name = "Info"
	info.Size = UDim2.new(0.6, -8, 1, 0)
	info.Position = UDim2.fromScale(0, 0)
	info.BackgroundTransparency = 1
	info.Parent = card

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(1, 0.36)
	titleLabel.Position = UDim2.fromScale(0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = `{petName} ({rarityText})`
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = info

	local detailLabel = Instance.new("TextLabel")
	detailLabel.Name = "Details"
	detailLabel.Size = UDim2.fromScale(1, 0.32)
	detailLabel.Position = UDim2.fromScale(0, 0.36)
	detailLabel.BackgroundTransparency = 1
	detailLabel.Font = Enum.Font.GothamMedium
	detailLabel.Text = `{group.count}/{group.requiredCount} normais · +{formatNumber(baseMult)} -> +{formatNumber(
		goldenMult
	)} Dano (2×)`
	detailLabel.TextColor3 = GOLDEN_COLOR
	detailLabel.TextScaled = true
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailLabel.Parent = info

	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "CostLabel"
	costLabel.Size = UDim2.fromScale(1, 0.3)
	costLabel.Position = UDim2.fromScale(0, 0.7)
	costLabel.BackgroundTransparency = 1
	costLabel.Font = Enum.Font.GothamBold
	costLabel.Text = `Custo: {group.gemCost} Gemas`
	costLabel.TextColor3 = if canAfford then Color3.fromRGB(100, 225, 255) else Color3.fromRGB(255, 118, 117)
	costLabel.TextScaled = true
	costLabel.TextXAlignment = Enum.TextXAlignment.Left
	costLabel.Parent = info

	local fuseBtn = Instance.new("TextButton")
	fuseBtn.Name = "FuseButton"
	fuseBtn.AnchorPoint = Vector2.new(1, 0.5)
	fuseBtn.Position = UDim2.fromScale(1, 0.5)
	fuseBtn.Size = UDim2.new(0.38, 0, 0, 48)
	fuseBtn.BackgroundColor3 = if fusePending
		then Color3.fromRGB(105, 112, 130)
		elseif canAfford then TAB_FUSION_ACTIVE_COLOR
		else Color3.fromRGB(115, 92, 70)
	fuseBtn.BorderSizePixel = 0
	fuseBtn.Font = Enum.Font.GothamBold
	fuseBtn.Text = if fusePending then "Fundindo..." else "Fundir"
	fuseBtn.TextColor3 = if canAfford and not fusePending
		then Color3.fromRGB(24, 27, 38)
		else Color3.fromRGB(255, 255, 255)
	fuseBtn.TextScaled = true
	fuseBtn.AutoButtonColor = not fusePending
	fuseBtn.Parent = card

	local btnConstraint = Instance.new("UISizeConstraint")
	btnConstraint.MinSize = Vector2.new(96, getMinTouchLocal())
	btnConstraint.Parent = fuseBtn

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = fuseBtn

	local btnPadding = Instance.new("UIPadding")
	btnPadding.PaddingLeft = UDim.new(0, 8)
	btnPadding.PaddingRight = UDim.new(0, 8)
	btnPadding.PaddingTop = UDim.new(0, 6)
	btnPadding.PaddingBottom = UDim.new(0, 6)
	btnPadding.Parent = fuseBtn

	local conn = fuseBtn.Activated:Connect(function()
		if fusePending then
			return
		end
		if onFuseCallback then
			onFuseCallback(group.batchUuids)
		end
	end)
	table.insert(fusionConnections, conn)
end

function PetInventoryUI.Refresh(data: Types.PlayerData?)
	local entries, totalBonus, equippedCount, inventoryCount = PetInventoryUI.BuildSortedEntries(data)
	currentEntryCount = #entries

	if bonusLabel then
		bonusLabel.Text = `Bônus Total: +{formatNumber(totalBonus)} Dano`
	end
	if equippedCountLabel then
		equippedCountLabel.Text = `Equipados: {equippedCount}/{GameConfig.MaxEquipped}`
	end
	if inventoryCountLabel then
		inventoryCountLabel.Text = `Inventário: {inventoryCount}/{GameConfig.MaxInventory}`
	end
	if toggleButton then
		toggleButton.Text = `Pets ({equippedCount}/{GameConfig.MaxEquipped})`
	end

	clearCards()
	clearFusionCards()

	local grid = gridFrame
	if grid then
		for index, entry in entries do
			createPetCard(entry, grid)
			local card = grid:FindFirstChild(`PetCard_{entry.uuid}`)
			if card and card:IsA("GuiObject") then
				card.LayoutOrder = index
			end
		end
		updateGridLayout()
	end

	local groups = Inventory.getFusableGroups(data :: any, PetsConfig :: any, FusionConfig :: any)
	local playerGems = if data and type(data.Gems) == "number" then data.Gems else 0

	if fusionTabBtn then
		fusionTabBtn.Text = if #groups > 0 then `Fusão (5->1) · {#groups}` else "Fusão (5->1)"
	end
	if fusionGemsLabel then
		fusionGemsLabel.Text = `Gemas: {formatNumber(playerGems)}`
	end
	if fusionEmptyLabel then
		fusionEmptyLabel.Visible = #groups == 0
	end
	local list = fusionListFrame
	if list then
		for index, group in groups do
			createFusionCard(group, playerGems, index, list)
		end
	end

	applyTabVisuals()
end

function PetInventoryUI.Mount(onToggle: TogglePetCallback, onFuse: FusePetsCallback?)
	PetInventoryUI.Destroy()
	onToggleCallback = onToggle
	onFuseCallback = onFuse
	activeTab = "inventory"

	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "PetInventoryGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local scale = Instance.new("UIScale")
	scale.Name = "ResponsiveScale"
	scale.Scale = 1
	scale.Parent = gui
	uiScale = scale

	-- Botão flutuante mobile-first para abrir/fechar o inventário de Pets (lateral direita, sem sobrepor moedas)
	local openBtn = Instance.new("TextButton")
	openBtn.Name = "PetsToggleButton"
	openBtn.AnchorPoint = Vector2.new(1, 0.5)
	openBtn.Position = UDim2.fromScale(0.98, 0.5)
	openBtn.Size = UDim2.fromScale(0.14, 0.09)
	openBtn.BackgroundColor3 = Color3.fromRGB(255, 107, 129)
	openBtn.BorderSizePixel = 0
	openBtn.Font = Enum.Font.GothamBold
	openBtn.Text = `Pets (0/{GameConfig.MaxEquipped})`
	openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	openBtn.TextScaled = true
	openBtn.Parent = gui
	toggleButton = openBtn

	local openBtnMinSize = Instance.new("UISizeConstraint")
	openBtnMinSize.MinSize = Vector2.new(96, 58)
	openBtnMinSize.MaxSize = Vector2.new(220, 76)
	openBtnMinSize.Parent = openBtn
	openBtnConstraint = openBtnMinSize

	local openBtnCorner = Instance.new("UICorner")
	openBtnCorner.CornerRadius = UDim.new(0, 14)
	openBtnCorner.Parent = openBtn

	local openBtnStroke = Instance.new("UIStroke")
	openBtnStroke.Thickness = 2
	openBtnStroke.Color = Color3.fromRGB(255, 255, 255)
	openBtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	openBtnStroke.Parent = openBtn

	local openBtnPad = Instance.new("UIPadding")
	openBtnPad.PaddingLeft = UDim.new(0.08, 0)
	openBtnPad.PaddingRight = UDim.new(0.08, 0)
	openBtnPad.PaddingTop = UDim.new(0.12, 0)
	openBtnPad.PaddingBottom = UDim.new(0.12, 0)
	openBtnPad.Parent = openBtn

	-- Modal principal (Active = true evita que cliques atravessem para o BlockController)
	local modal = Instance.new("Frame")
	modal.Name = "PetsModal"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.fromScale(0.76, 0.78)
	modal.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
	modal.BorderSizePixel = 0
	modal.Active = true
	modal.Visible = false
	modal.Parent = gui
	modalFrame = modal

	local modalSizeConstraint = Instance.new("UISizeConstraint")
	modalSizeConstraint.MinSize = Vector2.new(280, 260)
	modalSizeConstraint.MaxSize = Vector2.new(860, 620)
	modalSizeConstraint.Parent = modal

	local modalCorner = Instance.new("UICorner")
	modalCorner.CornerRadius = UDim.new(0, 18)
	modalCorner.Parent = modal

	local modalStroke = Instance.new("UIStroke")
	modalStroke.Thickness = 3
	modalStroke.Color = Color3.fromRGB(255, 107, 129)
	modalStroke.Parent = modal

	local modalPadding = Instance.new("UIPadding")
	modalPadding.PaddingTop = UDim.new(0.03, 0)
	modalPadding.PaddingBottom = UDim.new(0.03, 0)
	modalPadding.PaddingLeft = UDim.new(0.03, 0)
	modalPadding.PaddingRight = UDim.new(0.03, 0)
	modalPadding.Parent = modal

	-- Cabeçalho
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT_PX)
	header.Position = UDim2.fromOffset(0, 0)
	header.BackgroundTransparency = 1
	header.Active = true
	header.Parent = modal

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -72, 1, 0)
	title.Position = UDim2.fromScale(0, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "Mochila de Pets"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.fromScale(1, 0.5)
	closeBtn.Size = UDim2.new(0.12, 0, 0, HEADER_HEIGHT_PX)
	closeBtn.BackgroundColor3 = Color3.fromRGB(235, 77, 75)
	closeBtn.BorderSizePixel = 0
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextScaled = true
	closeBtn.Parent = header

	local closeMinSize = Instance.new("UISizeConstraint")
	closeMinSize.MinSize = Vector2.new(58, 58)
	closeMinSize.MaxSize = Vector2.new(64, 64)
	closeMinSize.Parent = closeBtn
	closeBtnConstraint = closeMinSize

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 10)
	closeCorner.Parent = closeBtn

	-- Barra de status (Bônus, Equipados, Inventário)
	local statsBar = Instance.new("Frame")
	statsBar.Name = "StatsBar"
	statsBar.Size = UDim2.new(1, 0, 0, STATS_HEIGHT_PX)
	statsBar.Position = UDim2.fromOffset(0, HEADER_HEIGHT_PX + SECTION_GAP_PX)
	statsBar.BackgroundColor3 = Color3.fromRGB(34, 39, 54)
	statsBar.BorderSizePixel = 0
	statsBar.Active = true
	statsBar.Parent = modal

	local statsCorner = Instance.new("UICorner")
	statsCorner.CornerRadius = UDim.new(0, 10)
	statsCorner.Parent = statsBar

	local statsPadding = Instance.new("UIPadding")
	statsPadding.PaddingLeft = UDim.new(0.03, 0)
	statsPadding.PaddingRight = UDim.new(0.03, 0)
	statsPadding.PaddingTop = UDim.new(0.12, 0)
	statsPadding.PaddingBottom = UDim.new(0.12, 0)
	statsPadding.Parent = statsBar

	local bonus = Instance.new("TextLabel")
	bonus.Name = "BonusLabel"
	bonus.Size = UDim2.fromScale(0.38, 1)
	bonus.Position = UDim2.fromScale(0, 0)
	bonus.BackgroundTransparency = 1
	bonus.Font = Enum.Font.GothamBold
	bonus.Text = "Bônus Total: +0 Dano"
	bonus.TextColor3 = Color3.fromRGB(255, 221, 89)
	bonus.TextScaled = true
	bonus.TextXAlignment = Enum.TextXAlignment.Left
	bonus.Parent = statsBar
	bonusLabel = bonus

	local eqLabel = Instance.new("TextLabel")
	eqLabel.Name = "EquippedCountLabel"
	eqLabel.Size = UDim2.fromScale(0.3, 1)
	eqLabel.Position = UDim2.fromScale(0.39, 0)
	eqLabel.BackgroundTransparency = 1
	eqLabel.Font = Enum.Font.GothamBold
	eqLabel.Text = `Equipados: 0/{GameConfig.MaxEquipped}`
	eqLabel.TextColor3 = Color3.fromRGB(123, 237, 159)
	eqLabel.TextScaled = true
	eqLabel.Parent = statsBar
	equippedCountLabel = eqLabel

	local invLabel = Instance.new("TextLabel")
	invLabel.Name = "InventoryCountLabel"
	invLabel.Size = UDim2.fromScale(0.3, 1)
	invLabel.Position = UDim2.fromScale(0.7, 0)
	invLabel.BackgroundTransparency = 1
	invLabel.Font = Enum.Font.GothamBold
	invLabel.Text = `Inventário: 0/{GameConfig.MaxInventory}`
	invLabel.TextColor3 = Color3.fromRGB(200, 214, 229)
	invLabel.TextScaled = true
	invLabel.TextXAlignment = Enum.TextXAlignment.Right
	invLabel.Parent = statsBar
	inventoryCountLabel = invLabel

	-- Barra de abas (Mochila / Fusão 5 -> 1 Dourado)
	local tabsBar = Instance.new("Frame")
	tabsBar.Name = "TabsBar"
	tabsBar.Size = UDim2.new(1, 0, 0, TABS_HEIGHT_PX)
	tabsBar.Position = UDim2.fromOffset(0, TABS_TOP_OFFSET_PX)
	tabsBar.BackgroundTransparency = 1
	tabsBar.Active = true
	tabsBar.Parent = modal

	local invTab = Instance.new("TextButton")
	invTab.Name = "InventoryTabButton"
	invTab.Size = UDim2.fromScale(0.49, 1)
	invTab.Position = UDim2.fromScale(0, 0)
	invTab.BackgroundColor3 = TAB_ACTIVE_COLOR
	invTab.BorderSizePixel = 0
	invTab.Font = Enum.Font.GothamBold
	invTab.Text = "Mochila"
	invTab.TextColor3 = Color3.fromRGB(255, 255, 255)
	invTab.TextScaled = true
	invTab.Parent = tabsBar
	inventoryTabBtn = invTab

	local invTabConstraint = Instance.new("UISizeConstraint")
	invTabConstraint.MinSize = Vector2.new(96, MIN_TOUCH_PX)
	invTabConstraint.Parent = invTab
	inventoryTabConstraint = invTabConstraint

	local invTabCorner = Instance.new("UICorner")
	invTabCorner.CornerRadius = UDim.new(0, 10)
	invTabCorner.Parent = invTab

	local invTabPad = Instance.new("UIPadding")
	invTabPad.PaddingLeft = UDim.new(0, 8)
	invTabPad.PaddingRight = UDim.new(0, 8)
	invTabPad.PaddingTop = UDim.new(0, 6)
	invTabPad.PaddingBottom = UDim.new(0, 6)
	invTabPad.Parent = invTab

	local fuseTab = Instance.new("TextButton")
	fuseTab.Name = "FusionTabButton"
	fuseTab.Size = UDim2.fromScale(0.49, 1)
	fuseTab.Position = UDim2.fromScale(0.51, 0)
	fuseTab.BackgroundColor3 = TAB_INACTIVE_COLOR
	fuseTab.BorderSizePixel = 0
	fuseTab.Font = Enum.Font.GothamBold
	fuseTab.Text = "Fusão (5->1)"
	fuseTab.TextColor3 = GOLDEN_COLOR
	fuseTab.TextScaled = true
	fuseTab.Parent = tabsBar
	fusionTabBtn = fuseTab

	local fuseTabConstraint = Instance.new("UISizeConstraint")
	fuseTabConstraint.MinSize = Vector2.new(96, MIN_TOUCH_PX)
	fuseTabConstraint.Parent = fuseTab
	fusionTabConstraint = fuseTabConstraint

	local fuseTabCorner = Instance.new("UICorner")
	fuseTabCorner.CornerRadius = UDim.new(0, 10)
	fuseTabCorner.Parent = fuseTab

	local fuseTabPad = Instance.new("UIPadding")
	fuseTabPad.PaddingLeft = UDim.new(0, 8)
	fuseTabPad.PaddingRight = UDim.new(0, 8)
	fuseTabPad.PaddingTop = UDim.new(0, 6)
	fuseTabPad.PaddingBottom = UDim.new(0, 6)
	fuseTabPad.Parent = fuseTab

	-- Banner de feedback/erro amigável (fallback caso HudController não esteja disponível)
	local toast = Instance.new("TextLabel")
	toast.Name = "ToastBanner"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, CONTENT_TOP_OFFSET_PX + 6)
	toast.Size = UDim2.new(0.92, 0, 0, 48)
	toast.BackgroundColor3 = Color3.fromRGB(235, 77, 75)
	toast.BorderSizePixel = 0
	toast.Font = Enum.Font.GothamBold
	toast.Text = ""
	toast.TextColor3 = Color3.fromRGB(255, 255, 255)
	toast.TextScaled = true
	toast.TextWrapped = true
	toast.Active = true
	toast.Visible = false
	toast.ZIndex = 5
	toast.Parent = modal
	toastLabel = toast

	local toastTextConstraint = Instance.new("UITextSizeConstraint")
	toastTextConstraint.MaxTextSize = 18
	toastTextConstraint.Parent = toast

	local toastPadding = Instance.new("UIPadding")
	toastPadding.PaddingLeft = UDim.new(0, 10)
	toastPadding.PaddingRight = UDim.new(0, 10)
	toastPadding.PaddingTop = UDim.new(0, 4)
	toastPadding.PaddingBottom = UDim.new(0, 4)
	toastPadding.Parent = toast

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 8)
	toastCorner.Parent = toast

	-- Grade rolável de pets
	local scrolling = Instance.new("ScrollingFrame")
	scrolling.Name = "PetGrid"
	scrolling.Size = UDim2.new(1, 0, 1, -CONTENT_TOP_OFFSET_PX)
	scrolling.Position = UDim2.fromOffset(0, CONTENT_TOP_OFFSET_PX)
	scrolling.BackgroundColor3 = Color3.fromRGB(19, 22, 31)
	scrolling.BorderSizePixel = 0
	scrolling.ScrollBarThickness = SCROLLBAR_THICKNESS_PX
	scrolling.CanvasSize = UDim2.fromScale(0, 0)
	scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrolling.ScrollingDirection = Enum.ScrollingDirection.Y
	scrolling.Active = true
	scrolling.Parent = modal
	gridFrame = scrolling

	local scrollCorner = Instance.new("UICorner")
	scrollCorner.CornerRadius = UDim.new(0, 12)
	scrollCorner.Parent = scrolling

	local scrollPadding = Instance.new("UIPadding")
	scrollPadding.PaddingTop = UDim.new(0, GRID_PADDING_PX)
	scrollPadding.PaddingBottom = UDim.new(0, GRID_PADDING_PX)
	scrollPadding.PaddingLeft = UDim.new(0, GRID_PADDING_PX)
	scrollPadding.PaddingRight = UDim.new(0, GRID_PADDING_PX)
	scrollPadding.Parent = scrolling

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.Name = "GridLayout"
	gridLayout.CellSize = UDim2.fromOffset(140, 128)
	gridLayout.CellPadding = UDim2.fromOffset(GRID_GAP_PX, GRID_GAP_PX)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.FillDirectionMaxCells = 3
	gridLayout.Parent = scrolling
	gridLayoutRef = gridLayout

	table.insert(connections, scrolling:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateGridLayout))

	local empty = Instance.new("TextLabel")
	empty.Name = "EmptyStateLabel"
	empty.AnchorPoint = Vector2.new(0.5, 0.5)
	empty.Position = UDim2.new(0.5, 0, 0.5, CONTENT_TOP_OFFSET_PX * 0.5)
	empty.Size = UDim2.fromScale(0.8, 0.2)
	empty.BackgroundTransparency = 1
	empty.Font = Enum.Font.GothamBold
	empty.Text = "Você ainda não tem nenhum pet!\nCompre um ovo na Praça dos Doces para chocar seu primeiro amigo!"
	empty.TextColor3 = Color3.fromRGB(165, 177, 194)
	empty.TextScaled = true
	empty.TextWrapped = true
	empty.Visible = true
	empty.Parent = modal
	emptyLabel = empty

	-- Painel de Fusão (5 normais -> 1 Dourado 2x)
	local fuseContainer = Instance.new("Frame")
	fuseContainer.Name = "FusionPanel"
	fuseContainer.Size = UDim2.new(1, 0, 1, -CONTENT_TOP_OFFSET_PX)
	fuseContainer.Position = UDim2.fromOffset(0, CONTENT_TOP_OFFSET_PX)
	fuseContainer.BackgroundColor3 = Color3.fromRGB(19, 22, 31)
	fuseContainer.BorderSizePixel = 0
	fuseContainer.Active = true
	fuseContainer.Visible = false
	fuseContainer.Parent = modal
	fusionPanel = fuseContainer

	local fuseContainerCorner = Instance.new("UICorner")
	fuseContainerCorner.CornerRadius = UDim.new(0, 12)
	fuseContainerCorner.Parent = fuseContainer

	local fuseContainerPad = Instance.new("UIPadding")
	fuseContainerPad.PaddingTop = UDim.new(0, 10)
	fuseContainerPad.PaddingBottom = UDim.new(0, 10)
	fuseContainerPad.PaddingLeft = UDim.new(0, 10)
	fuseContainerPad.PaddingRight = UDim.new(0, 10)
	fuseContainerPad.Parent = fuseContainer

	local fuseHeader = Instance.new("Frame")
	fuseHeader.Name = "FusionHeader"
	fuseHeader.Size = UDim2.new(1, 0, 0, 38)
	fuseHeader.Position = UDim2.fromOffset(0, 0)
	fuseHeader.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
	fuseHeader.BorderSizePixel = 0
	fuseHeader.Parent = fuseContainer

	local fuseHeaderCorner = Instance.new("UICorner")
	fuseHeaderCorner.CornerRadius = UDim.new(0, 8)
	fuseHeaderCorner.Parent = fuseHeader

	local fuseHeaderPad = Instance.new("UIPadding")
	fuseHeaderPad.PaddingLeft = UDim.new(0, 10)
	fuseHeaderPad.PaddingRight = UDim.new(0, 10)
	fuseHeaderPad.PaddingTop = UDim.new(0, 4)
	fuseHeaderPad.PaddingBottom = UDim.new(0, 4)
	fuseHeaderPad.Parent = fuseHeader

	local fuseInfo = Instance.new("TextLabel")
	fuseInfo.Name = "FusionInfoLabel"
	fuseInfo.Size = UDim2.fromScale(0.7, 1)
	fuseInfo.Position = UDim2.fromScale(0, 0)
	fuseInfo.BackgroundTransparency = 1
	fuseInfo.Font = Enum.Font.GothamMedium
	fuseInfo.Text = "5 normais iguais (desequipados) -> 1 Dourado (2×)"
	fuseInfo.TextColor3 = GOLDEN_COLOR
	fuseInfo.TextScaled = true
	fuseInfo.TextXAlignment = Enum.TextXAlignment.Left
	fuseInfo.Parent = fuseHeader

	local fuseGems = Instance.new("TextLabel")
	fuseGems.Name = "FusionGemsLabel"
	fuseGems.Size = UDim2.fromScale(0.28, 1)
	fuseGems.Position = UDim2.fromScale(0.72, 0)
	fuseGems.BackgroundTransparency = 1
	fuseGems.Font = Enum.Font.GothamBold
	fuseGems.Text = "Gemas: 0"
	fuseGems.TextColor3 = Color3.fromRGB(100, 225, 255)
	fuseGems.TextScaled = true
	fuseGems.TextXAlignment = Enum.TextXAlignment.Right
	fuseGems.Parent = fuseHeader
	fusionGemsLabel = fuseGems

	local fuseList = Instance.new("ScrollingFrame")
	fuseList.Name = "FusionList"
	fuseList.Size = UDim2.new(1, 0, 1, -46)
	fuseList.Position = UDim2.fromOffset(0, 46)
	fuseList.BackgroundTransparency = 1
	fuseList.BorderSizePixel = 0
	fuseList.ScrollBarThickness = SCROLLBAR_THICKNESS_PX
	fuseList.CanvasSize = UDim2.fromScale(0, 0)
	fuseList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	fuseList.ScrollingDirection = Enum.ScrollingDirection.Y
	fuseList.Active = true
	fuseList.Parent = fuseContainer
	fusionListFrame = fuseList

	local fuseListLayout = Instance.new("UIListLayout")
	fuseListLayout.Name = "ListLayout"
	fuseListLayout.Padding = UDim.new(0, 8)
	fuseListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	fuseListLayout.Parent = fuseList

	local fuseEmpty = Instance.new("TextLabel")
	fuseEmpty.Name = "FusionEmptyLabel"
	fuseEmpty.AnchorPoint = Vector2.new(0.5, 0.5)
	fuseEmpty.Position = UDim2.new(0.5, 0, 0.5, 20)
	fuseEmpty.Size = UDim2.fromScale(0.84, 0.3)
	fuseEmpty.BackgroundTransparency = 1
	fuseEmpty.Font = Enum.Font.GothamBold
	fuseEmpty.Text =
		"Nenhum grupo pronto para fusão!\nJunte 5 pets normais iguais e não equipados para criar 1 Dourado (2× dano)."
	fuseEmpty.TextColor3 = Color3.fromRGB(165, 177, 194)
	fuseEmpty.TextScaled = true
	fuseEmpty.TextWrapped = true
	fuseEmpty.Visible = true
	fuseEmpty.Parent = fuseContainer
	fusionEmptyLabel = fuseEmpty

	-- Conexões de UI
	table.insert(
		connections,
		invTab.Activated:Connect(function()
			activeTab = "inventory"
			applyTabVisuals()
			updateGridLayout()
		end)
	)

	table.insert(
		connections,
		fuseTab.Activated:Connect(function()
			activeTab = "fusion"
			applyTabVisuals()
		end)
	)

	table.insert(
		connections,
		openBtn.Activated:Connect(function()
			modal.Visible = not modal.Visible
			if modal.Visible then
				updateGridLayout()
			end
		end)
	)

	table.insert(
		connections,
		closeBtn.Activated:Connect(function()
			modal.Visible = false
		end)
	)

	local viewportConn: RBXScriptConnection? = nil
	local function bindCamera()
		if viewportConn then
			viewportConn:Disconnect()
			viewportConn = nil
		end
		local camera = Workspace.CurrentCamera
		if camera then
			local conn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
			viewportConn = conn
			table.insert(connections, conn)
		end
		updateResponsiveScale()
	end

	bindCamera()
	table.insert(connections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))

	gui.Parent = playerGui
	screenGui = gui
	applyTabVisuals()
	updateResponsiveScale()
end

function PetInventoryUI.Destroy()
	clearCards()
	clearFusionCards()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(pendingUuids)
	fusePending = false
	activeTab = "inventory"
	currentEntryCount = 0

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	uiScale = nil
	modalFrame = nil
	bonusLabel = nil
	equippedCountLabel = nil
	inventoryCountLabel = nil
	toastLabel = nil
	gridFrame = nil
	gridLayoutRef = nil
	emptyLabel = nil
	fusionPanel = nil
	fusionListFrame = nil
	fusionEmptyLabel = nil
	fusionGemsLabel = nil
	inventoryTabBtn = nil
	fusionTabBtn = nil
	inventoryTabConstraint = nil
	fusionTabConstraint = nil
	toggleButton = nil
	openBtnConstraint = nil
	closeBtnConstraint = nil
	onToggleCallback = nil
	onFuseCallback = nil
end

return PetInventoryUI
