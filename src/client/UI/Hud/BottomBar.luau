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
	for index, text in { "AUTO-CLICK", "x3 OVOS" } do
		local button = Theme.Button(
			root,
			if index == 1 then "AutoClick" else "TripleEggs",
			text,
			if index == 1 then Theme.Colors.Pets else Theme.Colors.Red,
			action
		)
		button.Position = UDim2.fromOffset((index - 1) * 228, 0)
		button.Size = UDim2.fromOffset(212, 64)
		table.insert(buttons, button)
	end
	return { Root = root, Scale = scale, Buttons = buttons }
end
return BottomBar
