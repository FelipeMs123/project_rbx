--!strict
-- Effects.luau (ReplicatedStorage.Shared.Config.Effects)
-- Dono: Squad A. Constantes visuais, durações e limites de efeitos de quebra de bloco.

local ConfettiColors: { Color3 } = table.freeze({
	Color3.fromRGB(255, 110, 190), -- rosa doce
	Color3.fromRGB(255, 225, 100), -- amarelo limão
	Color3.fromRGB(115, 215, 255), -- azul algodão
	Color3.fromRGB(125, 245, 185), -- menta
	Color3.fromRGB(255, 165, 95), -- laranja caramelo
})

local BlockTypeColors: { [string]: Color3 } = table.freeze({
	GummyBlock = Color3.fromRGB(255, 110, 190),
	LollipopBlock = Color3.fromRGB(255, 175, 95),
	ChocoBlock = Color3.fromRGB(255, 210, 125),
	CloudBlock = Color3.fromRGB(140, 225, 255),
})

local Effects = {
	-- Limites simultâneos e cache de posição
	MaxActiveBursts = 8,
	MaxActiveFloatingRewards = 10,
	MaxIdentifierLength = 64,
	PositionCacheTtlSeconds = 3,
	CacheSweepIntervalSeconds = 5,
	AnchorLifetime = 0.9,

	-- Billboard de vida dos blocos
	BlockBillboardMaxDistance = 30,
	BlockBillboardAttackVisibleSeconds = 3,

	-- Confete ao quebrar bloco
	ConfettiCount = 24,
	ConfettiLifetimeMin = 0.4,
	ConfettiLifetimeMax = 0.75,
	ConfettiSpeedMin = 6,
	ConfettiSpeedMax = 14,
	ConfettiGravityY = -18,
	ConfettiSpreadDegrees = 180,
	ConfettiRotSpeedMin = -240,
	ConfettiRotSpeedMax = 240,
	ConfettiRotationMin = 0,
	ConfettiRotationMax = 360,
	ConfettiSize = 0.28,
	ConfettiColors = ConfettiColors,
	BlockTypeColors = BlockTypeColors,

	-- Brilho ao quebrar bloco
	GlowDuration = 0.35,
	GlowStartSize = 2,
	GlowEndSize = 9,
	GlowStartTransparency = 0.25,
	GlowLightRange = 14,
	GlowLightBrightness = 2.5,
	GlowDefaultColor = Color3.fromRGB(255, 240, 175),

	-- Texto flutuante "+N moedas"
	RewardFlyDuration = 0.75,
	RewardFadeDelay = 0.45,
	RewardFadeDuration = 0.3,
	RewardRisePixels = 70,
	RewardJitterPixels = 18,
	RewardFallbackYScale = 0.65,
	RewardScreenPaddingPixels = 24,
	RewardAnchorX = 0.5,
	RewardAnchorY = 0.5,
	RewardLabelWidth = 220,
	RewardLabelHeight = 32,
	RewardTextSize = 22,
	RewardGemTextSize = 18,
	RewardGemOffsetY = 24,
	RewardCoinColor = Color3.fromRGB(255, 220, 80),
	RewardGemColor = Color3.fromRGB(100, 225, 255),
	RewardStrokeColor = Color3.fromRGB(35, 18, 45),
}

return table.freeze(Effects)
