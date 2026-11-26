--!strict
-- BlockEffects.luau (StarterPlayerScripts.Client.UI.Effects.BlockEffects)
-- Dono: Squad A. Efeitos visuais de quebra de bloco (confete, brilho e "+N moedas" voando).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Effects = require(ReplicatedStorage.Shared.Config.Effects)
local Format = require(ReplicatedStorage.Shared.Logic.Format)

local BlockEffects = {}

local activeBursts = 0
local activeRewards: { Frame } = {}
local screenGui: ScreenGui? = nil
local rng = Random.new()

local function getGlowColor(blockType: string): Color3
	return Effects.BlockTypeColors[blockType] or Effects.GlowDefaultColor
end

local function buildConfettiColorSequence(blockType: string): ColorSequence
	local colors = Effects.ConfettiColors
	local count = #colors
	if count == 0 then
		return ColorSequence.new(getGlowColor(blockType))
	end
	if count == 1 then
		return ColorSequence.new(colors[1])
	end

	local keypoints: { ColorSequenceKeypoint } = table.create(count)
	for index, color in colors do
		local alpha = (index - 1) / (count - 1)
		table.insert(keypoints, ColorSequenceKeypoint.new(alpha, color))
	end
	return ColorSequence.new(keypoints)
end

local function createBreakAnchor(position: Vector3): Part
	local anchor = Instance.new("Part")
	anchor.Name = "CandyBlockBreakEffect"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = Workspace
	return anchor
end

local function getScreenGui(): ScreenGui?
	if screenGui and screenGui.Parent then
		return screenGui
	end
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)
	if not playerGui or not playerGui:IsA("PlayerGui") then
		return nil
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CandyEffects"
	gui.DisplayOrder = -1
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	screenGui = gui
	return gui
end

local function projectRewardPosition(gui: ScreenGui, worldPosition: Vector3?, containerHeight: number): UDim2
	local jitterX = rng:NextNumber(-Effects.RewardJitterPixels, Effects.RewardJitterPixels)
	local camera = Workspace.CurrentCamera
	if camera and worldPosition then
		local screenPoint, onScreen = camera:WorldToScreenPoint(worldPosition)
		if onScreen and screenPoint.Z > 0 then
			-- WorldToScreenPoint já desconta o GuiInset e coincide com o referencial local de ScreenGui com CoreUISafeInsets.
			local localX = screenPoint.X + jitterX
			local localY = screenPoint.Y
			local size = gui.AbsoluteSize
			local padding = Effects.RewardScreenPaddingPixels
			local leftExtent = Effects.RewardLabelWidth * Effects.RewardAnchorX
			local rightExtent = Effects.RewardLabelWidth * (1 - Effects.RewardAnchorX)
			local topExtent = containerHeight * Effects.RewardAnchorY
			local bottomExtent = containerHeight * (1 - Effects.RewardAnchorY)
			local minX = padding + leftExtent
			local maxX = size.X - padding - rightExtent
			local minY = padding + topExtent + Effects.RewardRisePixels
			local maxY = size.Y - padding - bottomExtent
			localX = if minX <= maxX then math.clamp(localX, minX, maxX) else size.X * Effects.RewardAnchorX
			localY = if minY <= maxY then math.clamp(localY, minY, maxY) else size.Y * Effects.RewardAnchorY
			return UDim2.fromOffset(localX, localY)
		end
	end
	return UDim2.new(0.5, jitterX, Effects.RewardFallbackYScale, 0)
end

local function createRewardLabel(
	parent: Instance,
	text: string,
	textSize: number,
	color: Color3,
	offsetY: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.Active = false
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(0, offsetY)
	label.Size = UDim2.fromOffset(Effects.RewardLabelWidth, Effects.RewardLabelHeight)
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextStrokeColor3 = Effects.RewardStrokeColor
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = parent
	return label
end

local function removeRewardEntry(container: Frame)
	local index = table.find(activeRewards, container)
	if index then
		table.remove(activeRewards, index)
	end
	if container.Parent then
		container:Destroy()
	end
end

function BlockEffects.PlayBreak(position: Vector3, blockType: string)
	if activeBursts >= Effects.MaxActiveBursts then
		return
	end
	activeBursts += 1

	local anchor = createBreakAnchor(position)
	local released = false
	local function releaseBurst()
		if released then
			return
		end
		released = true
		activeBursts = math.max(0, activeBursts - 1)
	end
	anchor.Destroying:Connect(releaseBurst)
	task.delay(Effects.AnchorLifetime, releaseBurst)
	Debris:AddItem(anchor, Effects.AnchorLifetime)

	-- Confete colorido
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor

	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(Effects.ConfettiLifetimeMin, Effects.ConfettiLifetimeMax)
	emitter.Speed = NumberRange.new(Effects.ConfettiSpeedMin, Effects.ConfettiSpeedMax)
	emitter.SpreadAngle = Vector2.new(Effects.ConfettiSpreadDegrees, Effects.ConfettiSpreadDegrees)
	emitter.Acceleration = Vector3.new(0, Effects.ConfettiGravityY, 0)
	emitter.RotSpeed = NumberRange.new(Effects.ConfettiRotSpeedMin, Effects.ConfettiRotSpeedMax)
	emitter.Rotation = NumberRange.new(Effects.ConfettiRotationMin, Effects.ConfettiRotationMax)
	emitter.Size = NumberSequence.new(Effects.ConfettiSize)
	emitter.Color = buildConfettiColorSequence(blockType)
	emitter.Parent = attachment
	emitter:Emit(Effects.ConfettiCount)

	-- Brilho rápido ao quebrar
	local glowColor = getGlowColor(blockType)
	local glowPart = Instance.new("Part")
	glowPart.Name = "CandyBreakGlow"
	glowPart.Shape = Enum.PartType.Ball
	glowPart.Material = Enum.Material.Neon
	glowPart.Anchored = true
	glowPart.CanCollide = false
	glowPart.CanTouch = false
	glowPart.CanQuery = false
	glowPart.CastShadow = false
	glowPart.Color = glowColor
	glowPart.Transparency = Effects.GlowStartTransparency
	glowPart.Size = Vector3.one * Effects.GlowStartSize
	glowPart.Position = position
	glowPart.Parent = anchor

	local light = Instance.new("PointLight")
	light.Color = glowColor
	light.Range = Effects.GlowLightRange
	light.Brightness = Effects.GlowLightBrightness
	light.Parent = anchor

	local glowTweenInfo = TweenInfo.new(Effects.GlowDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(glowPart, glowTweenInfo, {
		Size = Vector3.one * Effects.GlowEndSize,
		Transparency = 1,
	}):Play()
	TweenService:Create(light, glowTweenInfo, {
		Brightness = 0,
	}):Play()
end

function BlockEffects.PlayReward(coins: number, gems: number, worldPosition: Vector3?)
	local safeCoins = if typeof(coins) == "number"
			and coins == coins
			and math.abs(coins) ~= math.huge
			and coins > 0
		then coins
		else 0
	local safeGems = if typeof(gems) == "number"
			and gems == gems
			and math.abs(gems) ~= math.huge
			and gems > 0
		then gems
		else 0
	if safeCoins == 0 and safeGems == 0 then
		return
	end

	local gui = getScreenGui()
	if not gui then
		return
	end

	while #activeRewards >= Effects.MaxActiveFloatingRewards do
		local oldest = table.remove(activeRewards, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end

	local hasBoth = safeCoins > 0 and safeGems > 0
	local totalHeight = Effects.RewardLabelHeight + (if hasBoth then Effects.RewardGemOffsetY else 0)
	local startPosition = projectRewardPosition(gui, worldPosition, totalHeight)

	local container = Instance.new("Frame")
	container.Name = "FloatingReward"
	container.Active = false
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(Effects.RewardAnchorX, Effects.RewardAnchorY)
	container.Size = UDim2.fromOffset(Effects.RewardLabelWidth, totalHeight)
	container.Position = startPosition
	container.Parent = gui
	table.insert(activeRewards, container)

	local labels: { TextLabel } = {}
	if safeCoins > 0 then
		table.insert(
			labels,
			createRewardLabel(
				container,
				`+{Format.abbreviate(safeCoins)} moedas`,
				Effects.RewardTextSize,
				Effects.RewardCoinColor,
				0
			)
		)
	end
	if safeGems > 0 then
		table.insert(
			labels,
			createRewardLabel(
				container,
				`+{Format.abbreviate(safeGems)} gemas`,
				Effects.RewardGemTextSize,
				Effects.RewardGemColor,
				if hasBoth then Effects.RewardGemOffsetY else 0
			)
		)
	end

	local endPosition = UDim2.new(
		startPosition.X.Scale,
		startPosition.X.Offset,
		startPosition.Y.Scale,
		startPosition.Y.Offset - Effects.RewardRisePixels
	)
	TweenService:Create(
		container,
		TweenInfo.new(Effects.RewardFlyDuration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		{ Position = endPosition }
	):Play()

	task.delay(Effects.RewardFadeDelay, function()
		if not container.Parent then
			return
		end
		local fadeInfo = TweenInfo.new(Effects.RewardFadeDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		for _, label in labels do
			TweenService:Create(label, fadeInfo, {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		end
	end)

	task.delay(Effects.RewardFlyDuration, function()
		removeRewardEntry(container)
	end)
end

return BlockEffects
