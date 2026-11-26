--!strict
-- StarterPlayerScripts.Client.UI.Hud.MenuCoordinator | Dono: Squad A. Coordena os menus sem importar Controllers.
local MenuCoordinator = {}
type Setter = (boolean) -> ()
type Entry = {
	guiName: string,
	modalName: string,
	toggleName: string?,
	modal: GuiObject?,
	setter: Setter?,
}
local entries: { [string]: Entry } = {
	Pets = { guiName = "PetInventoryGui", modalName = "PetsModal", toggleName = "PetsToggleButton" },
	Rebirth = { guiName = "RebirthGui", modalName = "RebirthModal" },
	Daily = { guiName = "DailyRewards", modalName = "ModalOverlay", toggleName = "OpenDaily" },
	Settings = { guiName = "SoundSettings", modalName = "ModalOverlay", toggleName = "OpenSettings" },
	Eggs = { guiName = "EggsGui", modalName = "EggPromptPanel" },
}
local pending: string? = nil
local dailyBadge: ((boolean) -> ())? = nil
local availableBadge: GuiObject? = nil
local fusionOverlay: GuiObject? = nil
local coordinating = false

-- A Squad B pode registrar SetModalOpen sem um require de volta pelo HUD.
function MenuCoordinator.Register(key: string, setter: Setter): () -> ()
	local entry = entries[key]
	assert(entry, "Menu desconhecido")
	entry.setter = setter
	return function()
		if entry.setter == setter then
			entry.setter = nil
		end
	end
end

local function closeOthers(key: string)
	if coordinating then
		return
	end
	coordinating = true
	for otherKey, entry in entries do
		if otherKey ~= key then
			local modal = entry.modal
			if modal and modal.Visible then
				if entry.setter then
					entry.setter(false)
				else
					modal.Visible = false
				end
			end
		end
	end
	local fusion = fusionOverlay
	if key ~= "Pets" and fusion then
		fusion.Visible = false
	end
	coordinating = false
end

function MenuCoordinator.Open(key: string): boolean
	local entry = entries[key]
	if not entry then
		return false
	end
	-- Rebirth exige o setter original, que prepara confirmação, retry e renderização.
	if key == "Rebirth" and not entry.setter then
		return false
	end
	pending = key
	closeOthers(key)
	if entry.setter then
		entry.setter(true)
		pending = nil
	elseif entry.modal then
		entry.modal.Visible = true
		pending = nil
	end
	return true
end

function MenuCoordinator.SetDailyBadge(callback: (boolean) -> ())
	dailyBadge = callback
	local badge = availableBadge
	callback(badge ~= nil and badge.Visible)
end

function MenuCoordinator.Mount(playerGui: Instance): () -> ()
	local connections: { RBXScriptConnection } = {}
	local watched: { [Instance]: boolean } = {}
	local function track(connection: RBXScriptConnection)
		table.insert(connections, connection)
	end
	local function watchGui(screen: Instance)
		if not screen:IsA("ScreenGui") or watched[screen] then
			return
		end
		local key: string? = nil
		for name, entry in entries do
			if screen.Name == entry.guiName then
				key = name
				break
			end
		end
		if not key then
			return
		end
		local menuKey = key
		local entry = entries[menuKey]
		watched[screen] = true
		local found: { [string]: boolean } = {}
		local required = { entry.modalName }
		if entry.toggleName then
			table.insert(required, entry.toggleName)
		end
		if menuKey == "Daily" then
			table.insert(required, "AvailableBadge")
		end
		if menuKey == "Pets" then
			table.insert(required, "FusionConfirmOverlay")
		end
		local discovery: RBXScriptConnection? = nil
		local function inspect(item: Instance)
			if not item:IsA("GuiObject") or not table.find(required, item.Name) then
				return
			end
			if found[item.Name] then
				return
			end
			found[item.Name] = true
			if item.Name == entry.toggleName then
				item.Visible = false
			elseif item.Name == "AvailableBadge" then
				availableBadge = item
				local function updateBadge()
					if dailyBadge then
						dailyBadge(item.Visible)
					end
				end
				track(item:GetPropertyChangedSignal("Visible"):Connect(updateBadge))
				updateBadge()
			elseif item.Name == "FusionConfirmOverlay" then
				fusionOverlay = item
			else
				entry.modal = item
				track(item:GetPropertyChangedSignal("Visible"):Connect(function()
					if item.Visible then
						pending = nil
						closeOthers(menuKey)
					end
				end))
				if pending == menuKey then
					MenuCoordinator.Open(menuKey)
				end
			end
			local complete = true
			for _, name in required do
				if not found[name] then
					complete = false
				end
			end
			local connection = discovery
			if complete and connection then
				connection:Disconnect()
			end
		end
		-- Seu único observador de descendentes termina assim que os alvos fixos existem.
		local discoveryConn = screen.DescendantAdded:Connect(inspect)
		discovery = discoveryConn
		track(discoveryConn)
		for _, item in screen:GetDescendants() do
			inspect(item)
		end
		track(screen.Destroying:Connect(function()
			entry.modal = nil
			watched[screen] = nil
			if menuKey == "Daily" then
				availableBadge = nil
				if dailyBadge then
					dailyBadge(false)
				end
			elseif menuKey == "Pets" then
				fusionOverlay = nil
			end
		end))
	end
	track(playerGui.ChildAdded:Connect(watchGui))
	for _, child in playerGui:GetChildren() do
		watchGui(child)
	end
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, entry in entries do
			entry.modal = nil
		end
		pending = nil
		dailyBadge = nil
		availableBadge = nil
		fusionOverlay = nil
	end
end

return MenuCoordinator
