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
end
