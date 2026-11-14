--!nocheck
-- Areas.spec.luau (testes Lune de ReplicatedStorage.Shared.Logic.Areas)
-- Dono: Squad A. Casos de progressão e saldo para desbloqueio de áreas.
local Areas = require("../src/shared/Logic/Areas")

local config = {
	Start = { Order = 1, Price = 0 },
	Next = { Order = 2, Price = 100 },
	Last = { Order = 3, Price = 200 },
}

return function(t)
	local function expect(areaId, unlocked, coins, expectedOk, expectedErr)
		local ok, err = Areas.canUnlock(config, unlocked, areaId, coins)
		t.eq(ok, expectedOk)
		t.eq(err, expectedErr)
	end

	t.test("área inexistente", function()
		expect("Unknown", {}, 1000, false, "UNKNOWN_ITEM")
	end)
	t.test("área já liberada tem prioridade sobre saldo", function()
		expect("Next", { "Start", "Next" }, 0, false, "ALREADY_UNLOCKED")
	end)
	t.test("anterior bloqueada tem prioridade sobre saldo", function()
		expect("Last", { "Start" }, 0, false, "AREA_LOCKED")
		expect("Last", { "Start" }, 1000, false, "AREA_LOCKED")
	end)
	t.test("sem saldo", function()
		expect("Next", { "Start" }, 99, false, "NOT_ENOUGH_COINS")
	end)
	t.test("preço exato sem alterar a lista", function()
		local unlocked = { "Start" }
		expect("Next", unlocked, 100, true, nil)
		t.eq(#unlocked, 1)
		t.eq(unlocked[1], "Start")
	end)
	t.test("Order 1 dispensa área anterior e aceita preço zero", function()
		expect("Start", {}, 0, true, nil)
	end)
	t.test("ordem independe do nome e recusa configuração sem anterior", function()
		expect("Last", { "Next" }, 200, true, nil)
		local ok, err = Areas.canUnlock({ Last = config.Last }, {}, "Last", 1000)
		t.eq(ok, false)
		t.eq(err, "AREA_LOCKED")
	end)
end
