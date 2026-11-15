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
	local boxes = {
		{ id = "Next", min = { X = 8, Y = 0, Z = 0 }, max = { X = 20, Y = 10, Z = 10 } },
		{ id = "Start", min = { X = 0, Y = 0, Z = 0 }, max = { X = 10, Y = 10, Z = 10 } },
	}
	t.test("posição dentro de área bloqueada e limites inclusivos", function()
		t.eq(Areas.lockedAreaAt(boxes, { "Start" }, { X = 15, Y = 5, Z = 5 }), "Next")
		t.eq(Areas.lockedAreaAt(boxes, { "Start" }, { X = 20, Y = 10, Z = 10 }), "Next")
	end)
	t.test("posição fora das caixas em cada eixo", function()
		for _, position in
			{
				{ X = -1, Y = 5, Z = 5 },
				{ X = 21, Y = 5, Z = 5 },
				{ X = 15, Y = -1, Z = 5 },
				{ X = 15, Y = 11, Z = 5 },
				{ X = 15, Y = 5, Z = -1 },
				{ X = 15, Y = 5, Z = 11 },
			}
		do
			t.eq(Areas.lockedAreaAt(boxes, { "Start" }, position), nil)
		end
	end)
	t.test("área liberada prevalece na sobreposição em qualquer ordem", function()
		local position = { X = 10, Y = 5, Z = 5 }
		t.eq(Areas.lockedAreaAt(boxes, { "Start" }, position), nil)
		t.eq(Areas.lockedAreaAt({ boxes[2], boxes[1] }, { "Start" }, position), nil)
		t.eq(Areas.lockedAreaAt(boxes, { "Start", "Next" }, { X = 15, Y = 5, Z = 5 }), nil)
	end)
	t.test("listas vazias e caixas sem áreas liberadas", function()
		t.eq(Areas.lockedAreaAt({}, {}, { X = 5, Y = 5, Z = 5 }), nil)
		t.eq(Areas.lockedAreaAt(boxes, {}, { X = 5, Y = 5, Z = 5 }), "Start")
	end)
	t.test("última liberada usa maior Order e ignora ids desconhecidos", function()
		t.eq(Areas.lastUnlocked(config, { "Last", "Start", "Next", "Unknown" }), "Last")
		t.eq(Areas.lastUnlocked(config, { "Next", "Start" }), "Next")
		t.eq(Areas.lastUnlocked(config, { "Start" }), "Start")
		t.eq(Areas.lastUnlocked(config, { "Unknown" }), nil)
		t.eq(Areas.lastUnlocked(config, {}), nil)
		t.eq(Areas.lastUnlocked({}, { "Start" }), nil)
	end)

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
