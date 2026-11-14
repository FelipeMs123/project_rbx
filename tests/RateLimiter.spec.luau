--!nocheck
local RateLimiter = require("../src/shared/Logic/RateLimiter")

return function(t)
	t.test("aceita até o burst e depois recusa", function()
		local limiter = RateLimiter.new(15, 15)
		for _ = 1, 15 do
			t.ok(limiter:Allow("p", 0))
		end
		t.eq(limiter:Allow("p", 0), false, "16º clique no mesmo instante")
	end)

	t.test("recarrega com o tempo", function()
		local limiter = RateLimiter.new(15, 15)
		for _ = 1, 15 do
			limiter:Allow("p", 0)
		end
		t.eq(limiter:Allow("p", 1 / 15), true, "uma ficha depois de 1/15 s")
		t.eq(limiter:Allow("p", 1 / 15), false)
	end)

	t.test("15 cliques por segundo sustentados passam, 30 não", function()
		local limiter = RateLimiter.new(15, 15)
		local accepted = 0
		for i = 0, 299 do -- 30 cps durante 10 s
			if limiter:Allow("p", i / 30) then
				accepted += 1
			end
		end
		t.ok(accepted <= 15 * 10 + 15, `aceitou {accepted}`)
		t.ok(accepted >= 15 * 10, `aceitou {accepted}`)
	end)

	t.test("jogadores têm baldes separados", function()
		local limiter = RateLimiter.new(1, 1)
		t.ok(limiter:Allow("a", 0))
		t.ok(limiter:Allow("b", 0))
		limiter:Remove("a")
		t.ok(limiter:Allow("a", 0))
	end)
end
