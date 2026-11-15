--!strict
-- PetInventoryUI.luau (StarterPlayerScripts.Client.UI.Pets.PetInventoryUI)
-- Dono: Squad B. Interface mobile-first do inventário de pets (botão flutuante, modal, grade e avisos).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ErrorCodes = require(Shared.ErrorCodes)
local GameConfig = require(Shared.Config.Game)
local PetsConfig = require(Shared.Config.Pets)
local Types = require(Shared.Types)

local PetInventoryUI = {}

export type TogglePetCallback = (uuid: string, currentlyEquipped: boolean) -> ()

export type PetEntry = {
	uuid: string,
	petId: string,
	def: Types.PetDef,
	equipped: boolean,
}

local DEFAULT_RARITY_COLOR = Color3.fromRGB(165, 177, 194)

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
	[ErrorCodes.UNKNOWN_ITEM] = "Esse pet não foi reconhecido pelo jogo!",
	[ErrorCodes.TOO_FAR] = "Chegue mais perto para fazer isso!",
	[ErrorCodes.NOT_IMPLEMENTED] = "Essa função estará disponível em breve!",
}

local screenGui: ScreenGui? = nil
local uiScale: UIScale? = nil
local bonusLabel: TextLabel? = nil
local equippedCountLabel: TextLabel? = nil
local inventoryCountLabel: TextLabel? = nil
local toastLabel: TextLabel? = nil
local gridFrame: ScrollingFrame? = nil
local emptyLabel: TextLabel? = nil
local toggleButton: TextButton? = nil

local connections: { RBXScriptConnection } = {}
local cardConnections: { RBXScriptConnection } = {}
local onToggleCallback: TogglePetCallback? = nil
local pendingUuids: { [string]: boolean } = {}
local toastToken = 0

local function formatNumber(n: number): string
	if math.abs(n - math.round(n)) < 0.001 then
		return tostring(math.round(n))
	end
	return string.format("%.1f", n)
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
			local isEquipped = equippedSet[uuid] == true
			if isEquipped then
				equippedCount += 1
				totalBonus += def.Multiplier
			end
			table.insert(entries, {
				uuid = uuid,
				petId = petInstance.Id,
				def = def,
				equipped = isEquipped,
			})
		end
	end

	table.sort(entries, function(a: PetEntry, b: PetEntry): boolean
		if a.equipped ~= b.equipped then
			return a.equipped
		end
		if a.def.Multiplier ~= b.def.Multiplier then
			return a.def.Multiplier > b.def.Multiplier
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
	local isPending = pendingUuids[entry.uuid] == true

	local card = Instance.new("TextButton")
	card.Name = `PetCard_{entry.uuid}`
	card.BackgroundColor3 = if entry.equipped then Color3.fromRGB(45, 58, 82) else Color3.fromRGB(36, 40, 56)
	card.BorderSizePixel = 0
	card.Text = ""
	card.AutoButtonColor = not isPending

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(96, 110)
	sizeConstraint.Parent = card

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if entry.equipped then 3 else 2
	stroke.Color = if entry.equipped then Color3.fromRGB(46, 213, 115) else rarityColor
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
	rarityBadge.BackgroundColor3 = rarityColor
	rarityBadge.BorderSizePixel = 0
	rarityBadge.Font = Enum.Font.GothamBold
	rarityBadge.Text = rarityText
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
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = true
	nameLabel.Parent = card

	local multLabel = Instance.new("TextLabel")
	multLabel.Name = "MultiplierLabel"
	multLabel.Size = UDim2.fromScale(1, 0.2)
	multLabel.Position = UDim2.fromScale(0, 0.56)
	multLabel.BackgroundTransparency = 1
	multLabel.Font = Enum.Font.GothamBold
	multLabel.Text = `+{formatNumber(entry.def.Multiplier)} Dano`
	multLabel.TextColor3 = Color3.fromRGB(255, 221, 89)
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

function PetInventoryUI.Refresh(data: Types.PlayerData?)
	local entries, totalBonus, equippedCount, inventoryCount = PetInventoryUI.BuildSortedEntries(data)

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

	local grid = gridFrame
	if not grid then
		return
	end

	if emptyLabel then
		emptyLabel.Visible = #entries == 0
	end

	for index, entry in entries do
		createPetCard(entry, grid)
		local card = grid:FindFirstChild(`PetCard_{entry.uuid}`)
		if card and card:IsA("GuiObject") then
			card.LayoutOrder = index
		end
	end
end

function PetInventoryUI.Mount(onToggle: TogglePetCallback)
	PetInventoryUI.Destroy()
	onToggleCallback = onToggle

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

	-- Botão flutuante mobile-first para abrir/fechar o inventário de Pets
	local openBtn = Instance.new("TextButton")
	openBtn.Name = "PetsToggleButton"
	openBtn.AnchorPoint = Vector2.new(0, 0.5)
	openBtn.Position = UDim2.fromScale(0.02, 0.55)
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
	openBtnMinSize.MinSize = Vector2.new(88, 48)
	openBtnMinSize.MaxSize = Vector2.new(220, 76)
	openBtnMinSize.Parent = openBtn

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

	-- Modal principal
	local modal = Instance.new("Frame")
	modal.Name = "PetsModal"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.fromScale(0.76, 0.78)
	modal.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = gui

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
	header.Size = UDim2.fromScale(1, 0.13)
	header.Position = UDim2.fromScale(0, 0)
	header.BackgroundTransparency = 1
	header.Parent = modal

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(0.8, 1)
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
	closeBtn.Size = UDim2.fromScale(0.12, 0.9)
	closeBtn.BackgroundColor3 = Color3.fromRGB(235, 77, 75)
	closeBtn.BorderSizePixel = 0
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextScaled = true
	closeBtn.Parent = header

	local closeMinSize = Instance.new("UISizeConstraint")
	closeMinSize.MinSize = Vector2.new(44, 44)
	closeMinSize.MaxSize = Vector2.new(64, 64)
	closeMinSize.Parent = closeBtn

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 10)
	closeCorner.Parent = closeBtn

	-- Barra de status (Bônus, Equipados, Inventário)
	local statsBar = Instance.new("Frame")
	statsBar.Name = "StatsBar"
	statsBar.Size = UDim2.fromScale(1, 0.11)
	statsBar.Position = UDim2.fromScale(0, 0.14)
	statsBar.BackgroundColor3 = Color3.fromRGB(34, 39, 54)
	statsBar.BorderSizePixel = 0
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

	-- Banner de feedback/erro amigável
	local toast = Instance.new("TextLabel")
	toast.Name = "ToastBanner"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.fromScale(0.5, 0.26)
	toast.Size = UDim2.fromScale(0.92, 0.08)
	toast.BackgroundColor3 = Color3.fromRGB(235, 77, 75)
	toast.BorderSizePixel = 0
	toast.Font = Enum.Font.GothamBold
	toast.Text = ""
	toast.TextColor3 = Color3.fromRGB(255, 255, 255)
	toast.TextScaled = true
	toast.Visible = false
	toast.ZIndex = 5
	toast.Parent = modal
	toastLabel = toast

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 8)
	toastCorner.Parent = toast

	-- Grade rolável de pets
	local scrolling = Instance.new("ScrollingFrame")
	scrolling.Name = "PetGrid"
	scrolling.Size = UDim2.fromScale(1, 0.72)
	scrolling.Position = UDim2.fromScale(0, 0.28)
	scrolling.BackgroundColor3 = Color3.fromRGB(19, 22, 31)
	scrolling.BorderSizePixel = 0
	scrolling.ScrollBarThickness = 8
	scrolling.CanvasSize = UDim2.fromScale(0, 0)
	scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrolling.ScrollingDirection = Enum.ScrollingDirection.Y
	scrolling.Parent = modal
	gridFrame = scrolling

	local scrollCorner = Instance.new("UICorner")
	scrollCorner.CornerRadius = UDim.new(0, 12)
	scrollCorner.Parent = scrolling

	local scrollPadding = Instance.new("UIPadding")
	scrollPadding.PaddingTop = UDim.new(0.02, 0)
	scrollPadding.PaddingBottom = UDim.new(0.02, 0)
	scrollPadding.PaddingLeft = UDim.new(0.02, 0)
	scrollPadding.PaddingRight = UDim.new(0.02, 0)
	scrollPadding.Parent = scrolling

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.Name = "GridLayout"
	gridLayout.CellSize = UDim2.fromScale(0.3, 0.36)
	gridLayout.CellPadding = UDim2.fromScale(0.03, 0.04)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.FillDirectionMaxCells = 3
	gridLayout.Parent = scrolling

	local empty = Instance.new("TextLabel")
	empty.Name = "EmptyStateLabel"
	empty.AnchorPoint = Vector2.new(0.5, 0.5)
	empty.Position = UDim2.fromScale(0.5, 0.64)
	empty.Size = UDim2.fromScale(0.8, 0.16)
	empty.BackgroundTransparency = 1
	empty.Font = Enum.Font.GothamBold
	empty.Text = "Você ainda não tem nenhum pet!\nCompre um ovo na Praça dos Doces para chocar seu primeiro amigo!"
	empty.TextColor3 = Color3.fromRGB(165, 177, 194)
	empty.TextScaled = true
	empty.Visible = true
	empty.Parent = modal
	emptyLabel = empty

	-- Conexões de UI
	table.insert(
		connections,
		openBtn.Activated:Connect(function()
			modal.Visible = not modal.Visible
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
	updateResponsiveScale()
end

function PetInventoryUI.Destroy()
	clearCards()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(pendingUuids)

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	uiScale = nil
	bonusLabel = nil
	equippedCountLabel = nil
	inventoryCountLabel = nil
	toastLabel = nil
	gridFrame = nil
	emptyLabel = nil
	toggleButton = nil
	onToggleCallback = nil
end

return PetInventoryUI
