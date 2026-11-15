--!strict
-- StarterPlayerScripts.Client.UI.Tutorial.TutorialUI
-- Dono: Squad A. Faixa e guias do tutorial, sem capturar toques no mundo.

local TweenService = game:GetService("TweenService")
local TutorialUI = {}
TutorialUI.Height = 72

local screen: ScreenGui? = nil
local title: TextLabel? = nil
local icon: TextLabel? = nil
local progressLabel: TextLabel? = nil
local track: Frame? = nil
local fill: Frame? = nil
local arrow: BillboardGui? = nil
local highlight: Frame? = nil
local bannerFrame: Frame? = nil
local pulse: Tween? = nil

local function label(parent: Instance, name: string): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Active = false
	item.Font = Enum.Font.GothamBold
	item.TextColor3 = Color3.new(1, 1, 1)
	item.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 16
	limit.MaxTextSize = 22
	limit.Parent = item
	item.Parent = parent
	return item
end

function TutorialUI.Mount(playerGui: PlayerGui)
	if screen then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialGui"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 8)
	banner.Size = UDim2.new(1, -24, 0, TutorialUI.Height)
	banner.BackgroundColor3 = Color3.fromRGB(62, 36, 85)
	banner.BorderSizePixel = 0
	banner.Active = false
	banner.Parent = gui
	bannerFrame = banner
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(420, TutorialUI.Height)
	size.Parent = banner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = banner
	local symbol = label(banner, "Icon")
	symbol.Position = UDim2.fromOffset(8, 8)
	symbol.Size = UDim2.fromOffset(36, 40)
	icon = symbol
	local text = label(banner, "StepText")
	text.Position = UDim2.fromOffset(48, 4)
	text.Size = UDim2.new(1, -56, 0, 32)
	text.TextWrapped = true
	title = text
	local progress = label(banner, "Progress")
	progress.Position = UDim2.fromOffset(48, 38)
	progress.Size = UDim2.new(1, -56, 0, 20)
	progressLabel = progress
	local bar = Instance.new("Frame")
	bar.Name = "ProgressBar"
	bar.Position = UDim2.new(0, 48, 1, -7)
	bar.Size = UDim2.new(1, -56, 0, 4)
	bar.BackgroundColor3 = Color3.fromRGB(100, 78, 120)
	bar.BorderSizePixel = 0
	bar.Active = false
	bar.Parent = banner
	track = bar
	local amount = Instance.new("Frame")
	amount.Size = UDim2.fromScale(0, 1)
	amount.BackgroundColor3 = Color3.fromRGB(255, 222, 85)
	amount.BorderSizePixel = 0
	amount.Active = false
	amount.Parent = bar
	fill = amount
	gui.Parent = playerGui
	screen = gui
end

function TutorialUI.Show(text: string, symbol: string, value: number, target: number, suffix: string?)
	if screen then
		screen.Enabled = true
	end
	if title then
		title.Text = text
		title.Size = UDim2.new(1, -56, 0, if suffix then 32 else 56)
	end
	if icon then
		icon.Text = symbol
	end
	if progressLabel then
		progressLabel.Visible = suffix ~= nil
		progressLabel.Text = `{value}/{target} {suffix or ""}`
	end
	if track then
		track.Visible = suffix ~= nil
	end
	if fill then
		fill.Size = UDim2.fromScale(if target > 0 then math.clamp(value / target, 0, 1) else 0, 1)
	end
end

function TutorialUI.SetBannerVisible(visible: boolean)
	if bannerFrame then
		bannerFrame.Visible = visible
	end
end

function TutorialUI.SetTarget(part: BasePart?)
	if arrow and arrow.Adornee == part and part and part.Parent then
		return
	end
	if arrow then
		arrow:Destroy()
		arrow = nil
	end
	if not part or not screen then
		return
	end
	local guide = Instance.new("BillboardGui")
	guide.Name = "TutorialArrow"
	guide.Adornee = part
	guide.Size = UDim2.new(2, 40, 2, 44)
	guide.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 6, 0)
	guide.AlwaysOnTop = true
	guide.Active = false
	local text = label(guide, "Arrow")
	text.Size = UDim2.fromScale(1, 1)
	text.Text = "⬇"
	text.TextColor3 = Color3.fromRGB(255, 222, 85)
	text.TextStrokeTransparency = 0.2
	local limit = text:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		limit.MinTextSize = 36
		limit.MaxTextSize = 80
	end
	guide.Parent = screen
	arrow = guide
end

function TutorialUI.Highlight(button: GuiObject?)
	if highlight and highlight.Parent == button and button then
		return
	end
	if pulse then
		pulse:Cancel()
		pulse = nil
	end
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if not button then
		return
	end
	local frame = Instance.new("Frame")
	frame.Name = "TutorialHighlight"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.ZIndex = math.max(100, button.ZIndex + 1)
	frame.Parent = button
	highlight = frame
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Color = Color3.fromRGB(255, 222, 85)
	outline.Thickness = 4
	outline.Parent = frame
	local tween = TweenService:Create(
		outline,
		TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.7 }
	)
	pulse = tween
	tween:Play()
end

function TutorialUI.Hide()
	if screen then
		screen.Enabled = false
	end
	TutorialUI.SetTarget(nil)
	TutorialUI.Highlight(nil)
end

return TutorialUI
