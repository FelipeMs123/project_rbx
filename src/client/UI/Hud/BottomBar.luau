--!strict
-- StarterPlayerScripts.Client.UI.Hud.BottomBar | Dono: Squad A. Atalhos futuros de monetização.
local Theme = require(script.Parent.Theme)
local BottomBar = {}
function BottomBar.Create(parent: Instance, action: () -> ())
	local root = Theme.Frame(parent, "BottomBar")
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Size = UDim2.fromOffset(440, 64)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local buttons: { TextButton } = {}
	for index, entry in
		{
			{ name = "AutoClick", icon = "🖱️", text = "AUTO-CLICK", color = Theme.Colors.Pets },
			{ name = "TripleEggs", icon = "🥚", text = "x3 EGGS", color = Theme.Colors.Red },
		}
	do
		local button = Theme.Button(root, entry.name, "", entry.color, action)
		button.Position = UDim2.fromOffset((index - 1) * 228, 0)
		button.Size = UDim2.fromOffset(212, 64)
		local icon = Instance.new("TextLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 10, 0.5, 0)
		icon.Size = UDim2.fromOffset(36, 36)
		Theme.Text(icon, entry.icon, 28)
		icon.Parent = button
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Position = UDim2.new(0, 48, 0.5, 0)
		label.Size = UDim2.new(1, -56, 0.8, 0)
		Theme.Text(label, entry.text, 26)
		label.Parent = button
		table.insert(buttons, button)
	end
	return { Root = root, Scale = scale, Buttons = buttons }
end
return BottomBar
