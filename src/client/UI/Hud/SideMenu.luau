--!strict
-- StarterPlayerScripts.Client.UI.Hud.SideMenu | Dono: Squad A. Menu lateral e recompensa diária.
local Theme = require(script.Parent.Theme)
local SideMenu = {}
function SideMenu.Create(parent: Instance, actions: { [string]: () -> () })
	local root = Theme.Frame(parent, "SideMenu")
	root.Size = UDim2.fromOffset(96, 470)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local daily = Theme.Button(root, "DailyButton", "🎁  !", Theme.Colors.Orange, actions.Daily)
	daily.Size = UDim2.fromOffset(96, 60)
	for index, entry in
		{
			{ "Shop", "🛒", "SHOP" },
			{ "Pets", "🐾", "PETS" },
			{ "Inventory", "🎒", "INVENTORY" },
			{ "Settings", "⚙️", "SETTINGS" },
		}
	do
		local key = entry[1]
		local button = Theme.Button(root, key .. "Button", "", Theme.Colors[key], actions[key])
		button.Position = UDim2.fromOffset(0, 70 + (index - 1) * 100)
		button.Size = UDim2.fromOffset(96, 92)
		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromScale(1, 0.66)
		Theme.Text(icon, entry[2], 46)
		icon.Parent = button
		local caption = Instance.new("TextLabel")
		caption.BackgroundTransparency = 1
		caption.Position = UDim2.fromScale(0.03, 0.66)
		caption.Size = UDim2.fromScale(0.94, 0.30)
		Theme.Text(caption, entry[3], 20)
		caption.Parent = button
	end
	return { Root = root, Scale = scale }
end
return SideMenu
