--!strict
-- StarterPlayerScripts.Client.Controllers.HudController | Dono: Squad A. Saldos e avisos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local DataController = require(script.Parent.DataController)
local NetClient = require(script.Parent.Parent.Net.NetClient)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Messages = require(script.Parent.Parent.UI.Hud.Messages)

local HudController = {}
local gui: ScreenGui? = nil
local toastStack: Frame? = nil
local pending: { { text: string, kind: string } } = {}
local colors =
	{ info = Color3.fromRGB(50, 70, 110), error = Color3.fromRGB(165, 45, 65), reward = Color3.fromRGB(30, 115, 80) }

local function label(parent: Instance, text: string): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundColor3 = Color3.fromRGB(35, 29, 55)
	item.BackgroundTransparency = 0.1
	item.TextColor3 = Color3.new(1, 1, 1)
	item.Font = Enum.Font.GothamBold
	item.TextScaled = true
	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MaxTextSize = 19
	textConstraint.Parent = item
	item.TextWrapped = true
	item.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = item
	item.Parent = parent
	return item
end

function HudController.Toast(text: string, kind: string)
	local stack = toastStack
	if not stack then
		table.insert(pending, { text = text, kind = kind })
		return
	end
	local item = label(stack, text)
	item.Size = UDim2.new(1, 0, 0, 52)
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.BackgroundColor3 = colors[kind] or colors.info
	task.delay(2.5, function()
		item:Destroy()
	end)
end

function HudController.SetTopReserve(pixels: number)
	if pixels ~= pixels or math.abs(pixels) == math.huge then
		return
	end
	local stack = toastStack
	if stack then
		stack.Position = UDim2.new(0.5, 0, 0, math.max(0, pixels))
	end
end

function HudController.Init()
	-- O registro fica em Start: NetClient.On pode esperar a replicação do remote.
end

function HudController.Start()
	if gui then
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "CandyHud"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui = screen
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = screen
	-- O ScreenGui aplica o inset; a consulta também acompanha alterações da barra superior.
	local function updateInset()
		local topLeft = GuiService:GetGuiInset()
		root.Position = UDim2.fromOffset(0, if topLeft.Y > 0 then 8 else 12)
	end
	updateInset()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(updateInset)
	local panel = Instance.new("Frame")
	panel.BackgroundTransparency = 1
	-- Meio da lateral esquerda: o canto superior esquerdo é do chat do Roblox.
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.fromScale(0.02, 0.5)
	panel.Size = UDim2.fromScale(0.32, 0.18)
	panel.Parent = root
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(110, 100)
	constraint.MaxSize = Vector2.new(240, 112)
	constraint.Parent = panel
	for index, key in { "Coins", "Gems" } do
		local name = if key == "Coins" then "● Moedas" else "◆ Gemas"
		local item = label(panel, name .. ": 0")
		item.Position = UDim2.fromScale(0, (index - 1) * 0.5)
		item.Size = UDim2.new(1, 0, 0.5, -4)
		item.TextColor3 = if key == "Coins" then Color3.fromRGB(255, 220, 80) else Color3.fromRGB(100, 225, 255)
		local scale = Instance.new("UIScale")
		scale.Parent = item
		local previous: number? = nil
		local animation: Tween? = nil
		DataController.Observe(key, function(value: any)
			if type(value) ~= "number" then
				return
			end
			item.Text = name .. ": " .. Format.abbreviate(value)
			if previous and value > previous then
				if animation then
					animation:Cancel()
				end
				scale.Scale = 1.08
				local tween = TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 })
				animation = tween
				tween:Play()
			end
			previous = value
		end)
	end
	local stack = Instance.new("Frame")
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(0.5, 0)
	-- Topo central, estreito o bastante para não encostar no chat (canto superior esquerdo).
	stack.Position = UDim2.fromScale(0.5, 0)
	stack.Size = UDim2.fromScale(0.5, 0.6)
	stack.Parent = root
	local stackLimit = Instance.new("UISizeConstraint")
	stackLimit.MaxSize = Vector2.new(360, math.huge)
	stackLimit.Parent = stack
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = stack
	toastStack = stack
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, entry in pending do
		HudController.Toast(entry.text, entry.kind)
	end
	table.clear(pending)
	NetClient.On("Notify", function(code: any, payload: any)
		if code == "REWARD" and type(payload) == "table" then
			local coins = if type(payload.coins) == "number" then payload.coins else 0
			local gems = if type(payload.gems) == "number" then payload.gems else 0
			HudController.Toast(
				"+"
					.. Format.abbreviate(coins)
					.. " moedas"
					.. (if gems > 0 then " · +" .. Format.abbreviate(gems) .. " gemas" else ""),
				"reward"
			)
		else
			HudController.Toast(Messages.message(code, payload), "error")
		end
	end)
end

return HudController
