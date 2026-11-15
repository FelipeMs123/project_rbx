--!nocheck
local Daily = require("../src/shared/Logic/Daily")

return function(t)
	t.test("primeiro resgate começa no dia 1", function()
		local ok, streak = Daily.evaluate({ LastClaimDay = 0, Streak = 0 }, 100, 7)
		t.eq(ok, true)
		t.eq(streak, 1)
	end)

	t.test("mesmo dia ou dia anterior não permite resgate", function()
		for _, today in { 100, 99 } do
			local ok, streak = Daily.evaluate({ LastClaimDay = 100, Streak = 2 }, today, 7)
			t.eq(ok, false)
			t.eq(streak, nil)
		end
	end)

	t.test("dia seguinte avança e após o dia 7 volta ao 1", function()
		local ok, streak = Daily.evaluate({ LastClaimDay = 100, Streak = 2 }, 101, 7)
		t.eq(ok, true)
		t.eq(streak, 3)
		ok, streak = Daily.evaluate({ LastClaimDay = 100, Streak = 7 }, 101, 7)
		t.eq(ok, true)
		t.eq(streak, 1)
	end)

	t.test("um dia perdido recua um passo até o mínimo de 1", function()
		for _, case in { { 5, 4 }, { 1, 1 } } do
			local ok, streak = Daily.evaluate({ LastClaimDay = 100, Streak = case[1] }, 102, 7)
			t.eq(ok, true)
			t.eq(streak, case[2])
		end
	end)

	t.test("dois ou mais dias perdidos reiniciam a sequência", function()
		for _, today in { 103, 110 } do
			local ok, streak = Daily.evaluate({ LastClaimDay = 100, Streak = 5 }, today, 7)
			t.eq(ok, true)
			t.eq(streak, 1)
		end
	end)

	t.test("sequência inválida reinicia em 1", function()
		for _, invalid in { 0 / 0, 0, 99, 2.5 } do
			for _, today in { 101, 102, 103 } do
				local ok, streak = Daily.evaluate({ LastClaimDay = 100, Streak = invalid }, today, 7)
				t.eq(ok, true)
				t.eq(streak, 1)
			end
		end
	end)

	t.test("índice de dia muda na fronteira UTC", function()
		t.eq(Daily.dayIndex(86399), 0)
		t.eq(Daily.dayIndex(86400), 1)
	end)

	t.test("retorna a recompensa do dia ou nil fora do intervalo", function()
		local days = {
			{ Day = 1, Coins = 1, Gems = 0 },
			{ Day = 2, Coins = 2, Gems = 0 },
			{ Day = 3, Coins = 3, Gems = 1 },
		}
		t.eq(Daily.reward(days, 3), days[3])
		t.eq(Daily.reward(days, 0), nil)
		t.eq(Daily.reward(days, 4), nil)
	end)

	t.test("segundos até o próximo dia UTC", function()
		t.eq(Daily.secondsUntilNext(0), 86400)
		t.eq(Daily.secondsUntilNext(86399), 1)
	end)
end
