--!strict
-- StarterPlayerScripts.Client.UI.Hud.SideMenu | Dono: Squad A. Menu lateral e recompensa diária.
local Theme = require(script.Parent.Theme)
local SideMenu = {}

local function addIconAndCaption(button: TextButton, iconText: string, captionText: string): TextLabel
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 0.66)
	Theme.Text(icon, iconText, 54)
	icon.Parent = button
	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 1
	caption.Position = UDim2.fromScale(0.03, 0.66)
	caption.Size = UDim2.fromScale(0.94, 0.30)
	Theme.Text(caption, captionText, 22)
	caption.Parent = button
	return icon
end

function SideMenu.Create(parent: Instance, actions: { [string]: () -> () })
	local root = Theme.Frame(parent, "SideMenu")
	root.Size = UDim2.fromOffset(108, 492)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local daily = Theme.Button(root, "DailyButton", "", Theme.Colors.Orange, actions.Daily)
	daily.Size = UDim2.fromOffset(108, 60)
	local dailyIcon = addIconAndCaption(daily, "🎁", "DIÁRIO")
	for index, entry in
		{
			{ "Shop", "🛒", "LOJA" },
			{ "Pets", "🐾", "PETS" },
			{ "Inventory", "🎒", "MOCHILA" },
			{ "Settings", "⚙️", "AJUSTES" },
		}
	do
		local key = entry[1]
		local button = Theme.Button(root, key .. "Button", "", Theme.Colors[key], actions[key])
		button.Position = UDim2.fromOffset(0, 68 + (index - 1) * 108)
		button.Size = UDim2.fromOffset(108, 100)
		addIconAndCaption(button, entry[2], entry[3])
	end
	return { Root = root, Scale = scale, Daily = daily, DailyIcon = dailyIcon }
end
return SideMenu
