--!strict
-- StarterPlayerScripts.Client.UI.Hud.Theme | Dono: Squad A. Estilo compartilhado do HUD.
local Theme = {}
Theme.Colors = {
	Ink = Color3.fromRGB(48, 32, 48),
	Shop = Color3.fromRGB(57, 222, 73),
	Pets = Color3.fromRGB(36, 172, 249),
	Inventory = Color3.fromRGB(184, 112, 53),
	Settings = Color3.fromRGB(135, 143, 158),
	Orange = Color3.fromRGB(255, 138, 52),
	Red = Color3.fromRGB(255, 77, 87),
	Gold = Color3.fromRGB(255, 207, 50),
} :: { [string]: Color3 }
function Theme.Decorate(item: GuiObject, color: Color3)
	item.BackgroundColor3 = color
	item.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = item
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.Colors.Ink
	stroke.Thickness = 3
	stroke.Parent = item
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(195, 195, 195))
	gradient.Rotation = 90
	gradient.Parent = item
end
function Theme.Text(target: TextLabel | TextButton, text: string, size: number)
	-- Luau strict não deixa escrever propriedades numa união; as duas classes têm estas.
	local item = target :: any
	item.Text = text
	item.Font = Enum.Font.FredokaOne
	item.TextColor3 = Color3.new(1, 1, 1)
	item.TextStrokeColor3 = Theme.Colors.Ink
	item.TextStrokeTransparency = 0
	item.TextSize = size
	item.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.Parent = item
end
function Theme.Button(parent: Instance, name: string, text: string, color: Color3, action: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Active = true
	Theme.Decorate(button, color)
	Theme.Text(button, text, 28)
	button.Parent = parent
	button.Activated:Connect(action)
	return button
end
function Theme.Frame(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	return frame
end
return Theme
