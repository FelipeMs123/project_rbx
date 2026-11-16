--!strict
-- StarterPlayerScripts.Client.UI.Hud.TopBar | Dono: Squad A. Cápsulas de saldo e selo de rebirth.
local Theme = require(script.Parent.Theme)
local TopBar = {}
function TopBar.Create(parent: Instance, shop: () -> (), rebirth: () -> ())
	local root = Theme.Frame(parent, "TopBar")
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Size = UDim2.fromOffset(520, 116)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local labels: { [string]: TextLabel } = {}
	local pops: { [string]: UIScale } = {}
	for index, key in { "Coins", "Gems" } do
		local capsule = Theme.Frame(root, key)
		capsule.BackgroundTransparency = 0
		capsule.Size = UDim2.fromOffset(250, 62)
		capsule.Position = UDim2.fromOffset((index - 1) * 270, 0)
		Theme.Decorate(capsule, Color3.fromRGB(255, 252, 238))
		local pop = Instance.new("UIScale")
		pop.Parent = capsule
		pops[key] = pop
		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(58, 60)
		Theme.Text(icon, if key == "Coins" then "🪙" else "💎", 42)
		icon.Parent = capsule
		local value = Instance.new("TextLabel")
		value.BackgroundTransparency = 1
		value.Position = UDim2.fromOffset(58, 3)
		value.Size = UDim2.fromOffset(130, 56)
		Theme.Text(value, "0", 36)
		value.TextColor3 = if key == "Coins" then Theme.Colors.Gold else Theme.Colors.Pets
		value.Parent = capsule
		labels[key] = value
		local plus = Theme.Button(capsule, "Add" .. key, "+", Theme.Colors.Shop, shop)
		plus.Size = UDim2.fromOffset(56, 56)
		plus.Position = UDim2.fromOffset(192, 3)
	end
	local badge = Theme.Button(root, "RebirthBadge", "Rebirth: 0", Theme.Colors.Orange, rebirth)
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0, 72)
	badge.Size = UDim2.fromOffset(210, 56)
	return { Root = root, Scale = scale, Labels = labels, Pops = pops, Rebirth = badge }
end
return TopBar
