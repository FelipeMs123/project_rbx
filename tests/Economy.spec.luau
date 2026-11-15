--!nocheck
local Economy = require("../src/shared/Logic/Economy")

return function(t)
	t.test("isValidAmount recusa lixo de exploit", function()
		t.eq(Economy.isValidAmount(10), true)
		t.eq(Economy.isValidAmount(0.5), true)
		t.eq(Economy.isValidAmount(0), false, "zero")
		t.eq(Economy.isValidAmount(-5), false, "negativo")
		t.eq(Economy.isValidAmount(0 / 0), false, "NaN")
		t.eq(Economy.isValidAmount(math.huge), false, "infinito")
		t.eq(Economy.isValidAmount("10"), false, "string")
		t.eq(Economy.isValidAmount(nil), false, "nil")
	end)

	t.test("coinMultiplier", function()
		t.eq(Economy.coinMultiplier(0, 0.5), 1)
		t.eq(Economy.coinMultiplier(2, 0.5), 2)
		t.eq(Economy.coinMultiplier(-3, 0.5), 1, "rebirth negativo não reduz")
	end)

	t.test("applyCoinBonus arredonda para baixo", function()
		t.eq(Economy.applyCoinBonus(5, 0, 0.5), 5)
		t.eq(Economy.applyCoinBonus(5, 1, 0.5), 7)
		t.eq(Economy.applyCoinBonus(100, 3, 0.5), 250)
	end)

	t.test("applyMultipliers combina bônus e arredonda só no final", function()
		t.eq(Economy.applyMultipliers(5, {}), 5)
		t.eq(Economy.applyMultipliers(5, { 2, 3 }), 30)
		t.eq(Economy.applyMultipliers(7.5, { 2 }), 15)
		t.eq(Economy.applyMultipliers(5, { 1.5 }), 7)
		t.eq(Economy.applyMultipliers(0, { 2 }), 0)
	end)

	t.test("applyMultipliers ignora valores inválidos", function()
		t.eq(Economy.applyMultipliers(5, { 0 / 0, math.huge, -math.huge, -2, 0, 0.5, "2", false, {}, 1, 2 }), 10)
	end)

	t.test("applyMultipliers recusa overflow no produto de multiplicadores finitos", function()
		t.eq(Economy.applyMultipliers(1, { 1e200, 1e200 }), 0)
		t.eq(Economy.applyMultipliers(0, { 1e200, 1e200 }), 0, "zero vezes infinito não credita NaN")
	end)

	t.test("applyMultipliers recusa overflow da base vezes o produto", function()
		t.eq(Economy.applyMultipliers(1e308, { 2 }), 0)
	end)
end
