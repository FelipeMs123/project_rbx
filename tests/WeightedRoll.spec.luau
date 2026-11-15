--!nocheck
local WeightedRoll = require("../src/shared/Logic/WeightedRoll")

return function(t)
	local function fails(callback)
		local ok = pcall(callback)
		return not ok
	end

	t.test("seleciona pesos em ordem determinística e respeita fronteiras CandyEgg", function()
		local weights = { LollipopBunny = 10, CottonCat = 60, BearGummy = 30 }
		t.eq(WeightedRoll.pick(weights, 0), "BearGummy")
		t.eq(WeightedRoll.pick(weights, 0.299999), "BearGummy")
		t.eq(WeightedRoll.pick(weights, 0.3), "CottonCat")
		t.eq(WeightedRoll.pick(weights, 0.9), "LollipopBunny")
		t.eq(WeightedRoll.pick(weights, 0.999999), "LollipopBunny")
	end)

	t.test("respeita fronteiras ChocolateEgg e ignora pesos zero", function()
		local weights = { ChocolateDragon = 1, JellyUnicorn = 14, BearGummy = 50, LollipopBunny = 35, None = 0 }
		t.eq(WeightedRoll.pick(weights, 0), "BearGummy")
		t.eq(WeightedRoll.pick(weights, 0.5), "ChocolateDragon")
		t.eq(WeightedRoll.pick(weights, 0.51), "JellyUnicorn")
		t.eq(WeightedRoll.pick(weights, 0.65), "LollipopBunny")
		t.eq(WeightedRoll.pick(weights, 0.999999), "LollipopBunny")
	end)

	t.test("1000 entradas uniformes seguem a distribuição CandyEgg", function()
		local counts = { CottonCat = 0, BearGummy = 0, LollipopBunny = 0 }
		local weights = { CottonCat = 60, BearGummy = 30, LollipopBunny = 10 }
		for i = 0, 999 do
			local result = WeightedRoll.pick(weights, (i + 0.5) / 1000)
			counts[result] += 1
		end
		t.eq(counts.CottonCat, 600)
		t.eq(counts.BearGummy, 300)
		t.eq(counts.LollipopBunny, 100)
	end)

	t.test("recusa aleatoriedade e pesos inválidos, vazios ou não finitos", function()
		local nan = 0 / 0
		t.ok(fails(function()
			WeightedRoll.pick({}, 0)
		end))
		t.ok(fails(function()
			WeightedRoll.pick({ a = 0 }, 0)
		end))
		t.ok(fails(function()
			WeightedRoll.pick({ a = 1 }, -1)
		end))
		t.ok(fails(function()
			WeightedRoll.pick({ a = 1 }, 1)
		end))
		t.ok(fails(function()
			WeightedRoll.pick({ a = 1 }, nan)
		end))
		t.ok(fails(function()
			WeightedRoll.pick({ a = -1 }, 0)
		end))
		t.ok(fails(function()
			WeightedRoll.pick({ a = nan }, 0)
		end))
		t.ok(fails(function()
			WeightedRoll.pick({ a = math.huge }, 0)
		end))
		t.ok(fails(function()
			WeightedRoll.pick({ a = -math.huge }, 0)
		end))
	end)
end
