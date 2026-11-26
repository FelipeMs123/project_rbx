--!strict
-- StarterPlayerScripts.Client.UI.Hud.TopBar | Dono: Squad A. Cápsulas de saldo e selo de rebirth.
local Theme = require(script.Parent.Theme)
local TopBar = {}

local function createCoinIcon(parent: Instance): Frame
	local holder = Theme.Frame(parent, "Icon")
	holder.Size = UDim2.fromOffset(44, 44)
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, 8, 0.5, 0)

	local disc = Instance.new("Frame")
	disc.Name = "CoinDisc"
	disc.Size = UDim2.fromScale(1, 1)
	disc.BackgroundColor3 = Color3.fromRGB(255, 206, 38)
	disc.BorderSizePixel = 0
	disc.Parent = holder
	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(1, 0)
	outerCorner.Parent = disc
	local outerStroke = Instance.new("UIStroke")
	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outerStroke.Color = Theme.Colors.Ink
	outerStroke.Thickness = 2.5
	outerStroke.Parent = disc
	local outerGrad = Instance.new("UIGradient")
	outerGrad.Color = ColorSequence.new(Color3.fromRGB(255, 238, 120), Color3.fromRGB(235, 160, 18))
	outerGrad.Rotation = 90
	outerGrad.Parent = disc

	local inner = Instance.new("Frame")
	inner.Name = "InnerRing"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.68, 0.68)
	inner.BackgroundColor3 = Color3.fromRGB(245, 178, 22)
	inner.BorderSizePixel = 0
	inner.Parent = disc
	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(1, 0)
	innerCorner.Parent = inner
	local innerStroke = Instance.new("UIStroke")
	innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	innerStroke.Color = Color3.fromRGB(255, 236, 130)
	innerStroke.Thickness = 1.5
	innerStroke.Parent = inner

	return holder
end

function TopBar.Create(parent: Instance, shop: () -> (), rebirth: () -> ())
	local root = Theme.Frame(parent, "TopBar")
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Size = UDim2.fromOffset(520, 62)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local labels: { [string]: TextLabel } = {}
	local pops: { [string]: UIScale } = {}
	for index, key in { "Coins", "Gems" } do
		local capsule = Theme.Frame(root, key)
		capsule.Active = true
		capsule.BackgroundTransparency = 0
		capsule.Size = UDim2.fromOffset(250, 62)
		capsule.Position = UDim2.fromOffset((index - 1) * 270, 0)
		Theme.Decorate(capsule, Color3.fromRGB(255, 252, 238))
		local pop = Instance.new("UIScale")
		pop.Parent = capsule
		pops[key] = pop
		if key == "Coins" then
			createCoinIcon(capsule)
		else
			local icon = Instance.new("TextLabel")
			icon.Name = "Icon"
			icon.BackgroundTransparency = 1
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 8, 0.5, 0)
			icon.Size = UDim2.fromOffset(44, 44)
			Theme.Text(icon, "💎", 36)
			icon.Parent = capsule
		end
		local value = Instance.new("TextLabel")
		value.BackgroundTransparency = 1
		value.AnchorPoint = Vector2.new(0, 0.5)
		value.Position = UDim2.new(0, 56, 0.5, 0)
		value.Size = UDim2.fromOffset(132, 52)
		Theme.Text(value, "0", 36)
		value.TextColor3 = if key == "Coins" then Theme.Colors.Gold else Theme.Colors.Pets
		value.Parent = capsule
		labels[key] = value
		local plus = Theme.Button(capsule, "Add" .. key, "+", Theme.Colors.Shop, shop)
		plus.AnchorPoint = Vector2.new(0, 0.5)
		plus.Size = UDim2.fromOffset(56, 56)
		plus.Position = UDim2.new(0, 192, 0.5, 0)
	end
	local badge = Theme.Button(root, "RebirthBadge", "", Theme.Colors.Rebirth, rebirth)
	badge.Visible = false
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Size = UDim2.fromOffset(180, 48)
	local rebirthIcon = Instance.new("TextLabel")
	rebirthIcon.Name = "Icon"
	rebirthIcon.BackgroundTransparency = 1
	rebirthIcon.AnchorPoint = Vector2.new(0, 0.5)
	rebirthIcon.Position = UDim2.new(0, 10, 0.5, 0)
	rebirthIcon.Size = UDim2.fromOffset(30, 30)
	Theme.Text(rebirthIcon, "🔄", 26)
	rebirthIcon.Parent = badge
	local rebirthLabel = Instance.new("TextLabel")
	rebirthLabel.Name = "Label"
	rebirthLabel.BackgroundTransparency = 1
	rebirthLabel.AnchorPoint = Vector2.new(0, 0.5)
	rebirthLabel.Position = UDim2.new(0, 44, 0.5, 0)
	rebirthLabel.Size = UDim2.new(1, -52, 0.85, 0)
	Theme.Text(rebirthLabel, "Rebirth [0]", 24)
	rebirthLabel.TextXAlignment = Enum.TextXAlignment.Left
	rebirthLabel.Parent = badge
	return { Root = root, Scale = scale, Labels = labels, Pops = pops, Rebirth = badge, RebirthLabel = rebirthLabel }
end
return TopBar
