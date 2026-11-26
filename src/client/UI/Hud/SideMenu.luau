--!strict
-- StarterPlayerScripts.Client.UI.Hud.SideMenu | Dono: Squad A. Menu lateral em grade e recompensa diária.
local Theme = require(script.Parent.Theme)
local SideMenu = {}

local function addIconAndCaption(button: TextButton, iconText: string, captionText: string): TextLabel
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromScale(0, 0.04)
	icon.Size = UDim2.fromScale(1, 0.62)
	Theme.Text(icon, iconText, 44)
	icon.Parent = button
	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 1
	caption.Position = UDim2.fromScale(0.04, 0.66)
	caption.Size = UDim2.fromScale(0.92, 0.28)
	Theme.Text(caption, captionText, 18)
	caption.Parent = button
	return icon
end

local function addDailyDot(button: TextButton): Frame
	local dot = Instance.new("Frame")
	dot.Name = "DailyBadge"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -6, 0, 6)
	dot.Size = UDim2.fromOffset(18, 18)
	dot.BackgroundColor3 = Color3.fromRGB(255, 45, 55)
	dot.BorderSizePixel = 0
	dot.ZIndex = 4
	dot.Visible = false
	dot.Parent = button
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.Colors.Ink
	stroke.Thickness = 2
	stroke.Parent = dot
	return dot
end

function SideMenu.Create(parent: Instance, actions: { [string]: () -> () })
	local root = Theme.Frame(parent, "SideMenu")
	root.Size = UDim2.fromOffset(176, 268)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local daily = Theme.Button(root, "DailyButton", "", Theme.Colors.Orange, actions.Daily)
	daily.Size = UDim2.fromOffset(84, 84)
	local dailyIcon = addIconAndCaption(daily, "🎁", "DAILY")
	local dailyBadge = addDailyDot(daily)
	for index, entry in
		{
			{ "Shop", "🛒", "SHOP" },
			{ "Pets", "🐾", "PETS" },
			{ "Inventory", "🎒", "BACKPACK" },
			{ "Settings", "⚙️", "SETTINGS" },
		}
	do
		local key = entry[1]
		local button = Theme.Button(root, key .. "Button", "", Theme.Colors[key], actions[key])
		local col = index % 2
		local row = math.floor(index / 2)
		button.Position = UDim2.fromOffset(col * 92, row * 92)
		button.Size = UDim2.fromOffset(84, 84)
		addIconAndCaption(button, entry[2], entry[3])
	end
	return { Root = root, Scale = scale, Daily = daily, DailyIcon = dailyIcon, DailyBadge = dailyBadge }
end
return SideMenu
