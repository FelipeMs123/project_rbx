--!nocheck
-- RebirthHelpers.spec.luau (testes Lune de StarterPlayerScripts.Client.UI.Rebirth.RebirthHelpers)
-- Dono: Squad B. Cobre custo, multiplicadores, progresso, casos inválidos e tradução de erros.

local Economy = require("../src/shared/Logic/Economy")
local ErrorCodes = require("../src/shared/ErrorCodes")
local GameConfig = require("../src/shared/Config/Game")
local Rebirth = require("../src/shared/Logic/Rebirth")
local RebirthHelpers = require("../src/client/UI/Rebirth/RebirthHelpers")

return function(t)
	t.test("traduz todos os códigos de erro do ErrorCodes e trata entrada inválida", function()
		for _, code in pairs(ErrorCodes) do
			local translated = RebirthHelpers.translateError(code)
			t.ok(type(translated) == "string" and #translated > 0, `faltou tradução para {code}`)
		end

		t.ok(string.find(RebirthHelpers.translateError(ErrorCodes.NOT_ENOUGH_COINS), "moedas", 1, true) ~= nil)
		t.ok(string.find(RebirthHelpers.translateError(ErrorCodes.RATE_LIMITED), "instante", 1, true) ~= nil)
		t.ok(string.find(RebirthHelpers.translateError(ErrorCodes.DATA_NOT_LOADED), "carregando", 1, true) ~= nil)

		local fallbackNil = RebirthHelpers.translateError(nil)
		local fallbackUnknown = RebirthHelpers.translateError("UNKNOWN_ERR")
		t.eq(fallbackNil, fallbackUnknown)
		t.ok(#fallbackNil > 0)
	end)

	t.test("calcula custo de rebirth em paridade com Shared.Logic.Rebirth e trata inválidos", function()
		for r = 0, 4 do
			local expected = Rebirth.cost(r, GameConfig.RebirthBaseCost, GameConfig.RebirthCostGrowth)
			t.eq(RebirthHelpers.computeCost(r, GameConfig), expected)
			t.eq(RebirthHelpers.computeCost(r), expected)
		end

		t.eq(RebirthHelpers.computeCost(1.9, GameConfig), 25000)
		t.eq(RebirthHelpers.computeCost(-3, GameConfig), GameConfig.RebirthBaseCost)
		t.eq(RebirthHelpers.computeCost(0 / 0, GameConfig), GameConfig.RebirthBaseCost)
		t.eq(RebirthHelpers.computeCost(nil :: any, GameConfig), GameConfig.RebirthBaseCost)
		t.eq(RebirthHelpers.computeCost(math.huge, GameConfig), math.huge)
	end)

	t.test("calcula multiplicadores atual e próximo em paridade com Economy", function()
		for r = 0, 3 do
			local preview = RebirthHelpers.computeMultipliers(r, GameConfig)
			t.eq(preview.CurrentRebirths, r)
			t.eq(preview.NextRebirths, r + 1)
			t.eq(preview.CurrentMultiplier, Economy.coinMultiplier(r, GameConfig.RebirthCoinBonus))
			t.eq(preview.NextMultiplier, Economy.coinMultiplier(r + 1, GameConfig.RebirthCoinBonus))
			t.eq(preview.GemReward, GameConfig.RebirthGemReward)
		end

		local invalidNaN = RebirthHelpers.computeMultipliers(0 / 0, GameConfig)
		t.eq(invalidNaN.CurrentRebirths, 0)
		t.eq(invalidNaN.NextRebirths, 1)
		t.eq(invalidNaN.CurrentMultiplier, 1)

		local invalidNeg = RebirthHelpers.computeMultipliers(-5, GameConfig)
		t.eq(invalidNeg.CurrentRebirths, 0)
		t.eq(invalidNeg.CurrentMultiplier, 1)

		local invalidInf = RebirthHelpers.computeMultipliers(math.huge, GameConfig)
		t.eq(invalidInf.CurrentRebirths, 0)
		t.eq(invalidInf.CurrentMultiplier, 1)

		local defaultPreview = RebirthHelpers.computeMultipliers(1)
		t.eq(defaultPreview.CurrentMultiplier, 1.5)
		t.eq(defaultPreview.NextMultiplier, 2)
		t.eq(defaultPreview.GemReward, GameConfig.RebirthGemReward)
	end)

	t.test("calcula progresso de rebirth e protege contra NaN, nil, negativos e infinito", function()
		local zero = RebirthHelpers.computeProgress(0, 10000)
		t.eq(zero.Ratio, 0)
		t.eq(zero.Percent, 0)
		t.eq(zero.CanRebirth, false)
		t.eq(zero.MissingCoins, 10000)

		local almost = RebirthHelpers.computeProgress(9999, 10000)
		t.eq(almost.Percent, 99)
		t.eq(almost.CanRebirth, false)
		t.eq(almost.MissingCoins, 1)

		local exact = RebirthHelpers.computeProgress(10000, 10000)
		t.eq(exact.Ratio, 1)
		t.eq(exact.Percent, 100)
		t.eq(exact.CanRebirth, true)
		t.eq(exact.MissingCoins, 0)

		local over = RebirthHelpers.computeProgress(25000, 10000)
		t.eq(over.Ratio, 1)
		t.eq(over.Percent, 100)
		t.eq(over.CanRebirth, true)
		t.eq(over.MissingCoins, 0)

		local freeCost = RebirthHelpers.computeProgress(0, 0)
		t.eq(freeCost.CanRebirth, true)
		t.eq(freeCost.Percent, 100)

		local nanCoins = RebirthHelpers.computeProgress(0 / 0, 10000)
		t.eq(nanCoins.Ratio, 0)
		t.eq(nanCoins.Percent, 0)
		t.eq(nanCoins.CanRebirth, false)
		t.eq(nanCoins.MissingCoins, 10000)

		local negCoins = RebirthHelpers.computeProgress(-500, 10000)
		t.eq(negCoins.Ratio, 0)
		t.eq(negCoins.CanRebirth, false)
		t.eq(negCoins.MissingCoins, 10000)

		local infCoins = RebirthHelpers.computeProgress(math.huge, 10000)
		t.eq(infCoins.Ratio, 0)
		t.eq(infCoins.CanRebirth, false)
		t.eq(infCoins.MissingCoins, 10000)

		local nilCoins = RebirthHelpers.computeProgress(nil :: any, 10000)
		t.eq(nilCoins.CanRebirth, false)
		t.eq(nilCoins.MissingCoins, 10000)

		local infCost = RebirthHelpers.computeProgress(5000, math.huge)
		t.eq(infCost.Ratio, 0)
		t.eq(infCost.CanRebirth, false)
	end)

	t.test("formata números curtos corretamente", function()
		t.eq(RebirthHelpers.formatShortNumber(999), "999")
		t.eq(RebirthHelpers.formatShortNumber(10000), "10K")
		t.eq(RebirthHelpers.formatShortNumber(25000), "25K")
		t.eq(RebirthHelpers.formatShortNumber(156250), "156.2K")
		t.eq(RebirthHelpers.formatShortNumber(2500000), "2.5M")
		t.eq(RebirthHelpers.formatShortNumber(0 / 0), "0")
		t.eq(RebirthHelpers.formatShortNumber(math.huge), "0")
	end)

	t.test("métricas do modal de rebirth evitam vazamento no MinSize 320x330 e mantêm aviso legível", function()
		local metrics = RebirthHelpers.computeModalMetrics(330)
		t.ok(metrics.HeaderHeight >= metrics.CloseMinSize, "Header deve comportar CloseButton de 52px")
		t.ok(
			metrics.StepTwoButtonsBottom <= metrics.StepTwoHeight,
			"Botões de confirmação não podem vazar do StepTwoPanel"
		)
		t.ok(metrics.SummaryMinTextSize >= 12, "SummaryNotice deve ter MinTextSize >= 12")
		t.ok(metrics.TogglePositionYScale <= 0.37, "RebirthToggleButton deve ficar afastado acima do PetsToggleButton")
	end)
end
