--!nocheck
-- Testes de ReplicatedStorage.Shared.Logic.SoundRules | Dono: Squad A.
local Rules = require("../src/shared/Logic/SoundRules")

return function(t)
	t.test("som de cada tipo de bloco e tipo desconhecido", function()
		t.eq(Rules.breakSound("GummyBlock"), "BlockBreakCommon")
		t.eq(Rules.breakSound("LollipopBlock"), "BlockBreakCommon")
		t.eq(Rules.breakSound("ChocoBlock"), "BlockBreakRare")
		t.eq(Rules.breakSound("CloudBlock"), "BlockBreakEpic")
		t.eq(Rules.breakSound("Unknown"), nil)
	end)
	local box = { id = "CandyPlaza", min = { X = 0, Y = 0, Z = 0 }, max = { X = 10, Y = 10, Z = 10 } }
	t.test("caixa inclui centro e bordas", function()
		for _, n in { 0, 5, 10 } do
			t.eq(Rules.areaAt({ box }, { X = n, Y = n, Z = n }), "CandyPlaza")
		end
	end)
	t.test("fora em cada eixo, NaN e lista vazia", function()
		for _, axis in { "X", "Y", "Z" } do
			for _, n in { -1, 11, math.huge, 0 / 0 } do
				local point = { X = 5, Y = 5, Z = 5 }
				point[axis] = n
				t.eq(Rules.areaAt({ box }, point), nil)
			end
		end
		t.eq(Rules.areaAt({}, { X = 5, Y = 5, Z = 5 }), nil)
	end)
	t.test("sobreposição respeita ordem recebida", function()
		local second = { id = "ChocolateFalls", min = box.min, max = box.max }
		t.eq(Rules.areaAt({ second, box }, { X = 5, Y = 5, Z = 5 }), "ChocolateFalls")
	end)
end
