--!nocheck
-- tests/Format.spec | Dono: Squad A. Casos de exibição e limites numéricos.
local Format = require("../src/shared/Logic/Format")

return function(t)
	t.test("abrevia valores e preserva sinal", function()
		for _, case in
			{
				{ 0, "0" },
				{ 999, "999" },
				{ 1200, "1.2K" },
				{ 3400000, "3.4M" },
				{ 5600000000, "5.6B" },
				{ 7800000000000, "7.8T" },
				{ 1000, "1K" },
				{ -1200, "-1.2K" },
				{ 999999, "1M" },
				{ 999.99, "1K" },
				{ 12.34, "12.3" },
				{ -0.01, "0" },
			}
		do
			t.eq(Format.abbreviate(case[1]), case[2])
		end
	end)
	t.test("valores não finitos viram zero", function()
		t.eq(Format.abbreviate(0 / 0), "0")
		t.eq(Format.abbreviate(math.huge), "0")
		t.eq(Format.abbreviate(-math.huge), "0")
	end)
end
