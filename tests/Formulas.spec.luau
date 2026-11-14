--!nocheck
-- tests/Formulas.spec.luau (Lune). Dono: Squad A. Casos de dano e recompensa.
local Formulas = require("../src/shared/Logic/Formulas")

return function(t)
	t.test("dano soma base e bônus, inclusive fracionário", function()
		t.eq(Formulas.damage(1, 0), 1)
		t.eq(Formulas.damage(1, 12), 13)
		t.eq(Formulas.damage(1, 1.5), 2.5)
	end)
	t.test("um jogador recebe tudo", function()
		local r = Formulas.splitReward(25, 2, 10, { { key = "a", damage = 10 } })
		t.eq(r.a.coins, 25)
		t.eq(r.a.gems, 2)
	end)
	t.test("três jogadores e arredondamento para baixo", function()
		local r = Formulas.splitReward(11, 3, 10, {
			{ key = "a", damage = 5 },
			{ key = "b", damage = 3 },
			{ key = "c", damage = 2 },
		})
		t.eq(r.a.coins, 5)
		t.eq(r.b.coins, 3)
		t.eq(r.c.coins, 2)
		t.eq(r.a.gems, 3)
		t.eq(r.b.gems + r.c.gems, 0)
	end)
	t.test("overkill e golpes depois da morte não contam", function()
		local log = { { key = "a", damage = 9 }, { key = "b", damage = 100 }, { key = "c", damage = 10 } }
		local r = Formulas.splitReward(100, 1, 10, log)
		t.eq(r.a.coins, 90)
		t.eq(r.b.coins, 10)
		t.eq(r.a.gems, 1)
		t.eq(r.c, nil)
		t.eq(log[2].damage, 100)
	end)
	t.test("empate usa golpe mais recente entre os empatados", function()
		local r = Formulas.splitReward(9, 2, 9, {
			{ key = "a", damage = 4 },
			{ key = "b", damage = 2 },
			{ key = "b", damage = 2 },
			{ key = "c", damage = 1 },
		})
		t.eq(r.a.gems, 0)
		t.eq(r.b.gems, 2)
		t.eq(r.c.gems, 0)
	end)
	t.test("zero gemas não premia ninguém", function()
		local r = Formulas.splitReward(5, 0, 10, { { key = "a", damage = 10 } })
		t.eq(r.a.gems, 0)
	end)
	t.test("lista vazia e HP inválido não geram recompensa", function()
		t.eq(next(Formulas.splitReward(5, 1, 10, {})), nil)
		for _, hp in { 0, -1, 0 / 0, math.huge } do
			t.eq(next(Formulas.splitReward(5, 1, hp, { { key = "a", damage = 1 } })), nil)
		end
	end)
	t.test("ignora dano negativo, zero e NaN sem afetar desempate", function()
		local r = Formulas.splitReward(10, 1, 10, {
			{ key = "a", damage = 5 },
			{ key = "b", damage = 5 },
			{ key = "a", damage = 0 },
			{ key = "a", damage = -1 },
			{ key = "a", damage = 0 / 0 },
		})
		t.eq(r.a.coins, 5)
		t.eq(r.b.gems, 1)
		local invalid = Formulas.splitReward(10, 1, 10, {
			{ key = "x", damage = -1 },
			{ key = "x", damage = 0 / 0 },
			{ key = "a", damage = 2.5 },
		})
		t.eq(invalid.x, nil)
		t.eq(invalid.a.coins, 2)
	end)
end
