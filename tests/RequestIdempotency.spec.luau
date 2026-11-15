--!nocheck
-- RequestIdempotency.spec.luau (testes Lune de Shared.Logic.RequestIdempotency)
-- Dono: Squad B. Prova trava inFlight por jogador/requestId, cache limitado de sucesso,
-- liberação garantida via pcall em erros e limpeza em Remove().

local RequestIdempotency = require("../src/shared/Logic/RequestIdempotency")

return function(t)
	t.test("aceita chamadas legadas sem requestId e rejeita requestId inválido", function()
		local idem = RequestIdempotency.new(8)
		local player = { UserId = 1 }
		local calls = 0

		local r1 = idem:Execute(player, nil, function()
			calls += 1
			return { ok = true, data = { count = calls } }
		end)
		local r2 = idem:Execute(player, nil, function()
			calls += 1
			return { ok = true, data = { count = calls } }
		end)
		t.eq(r1.ok, true)
		t.eq(r1.data.count, 1)
		t.eq(r2.ok, true)
		t.eq(r2.data.count, 2)
		t.eq(calls, 2)

		for _, badId in { "", 123, true, {}, string.rep("x", 65) } do
			local badRes = idem:Execute(player, badId, function()
				calls += 1
				return { ok = true }
			end)
			t.eq(badRes.ok, false)
			t.eq(badRes.err, "INVALID_ARGS")
		end
		t.eq(calls, 2, "executor não deve ser chamado para requestId inválido")
	end)

	t.test("bloqueia chamada simultânea inFlight com RATE_LIMITED sem executar duas vezes", function()
		local idem = RequestIdempotency.new(8)
		local p1 = { UserId = 1 }
		local p2 = { UserId = 2 }
		local executions = 0
		local concurrentRes = nil
		local otherPlayerRes = nil

		local firstRes = idem:Execute(p1, "req-1", function()
			executions += 1
			t.eq(idem:IsInFlight(p1, "req-1"), true)

			-- Mesmo jogador + mesmo requestId durante inFlight -> RATE_LIMITED
			concurrentRes = idem:Execute(p1, "req-1", function()
				executions += 1
				return { ok = true }
			end)

			-- Outro jogador com mesmo requestId é isolado e executa normalmente
			otherPlayerRes = idem:Execute(p2, "req-1", function()
				return { ok = true, data = { owner = 2 } }
			end)

			return { ok = true, data = { owner = 1 } }
		end)

		t.eq(executions, 1, "mesmo requestId em voo não pode executar duas vezes")
		t.eq(concurrentRes.ok, false)
		t.eq(concurrentRes.err, "RATE_LIMITED")
		t.eq(otherPlayerRes.ok, true)
		t.eq(otherPlayerRes.data.owner, 2)
		t.eq(firstRes.ok, true)
		t.eq(firstRes.data.owner, 1)
		t.eq(idem:IsInFlight(p1, "req-1"), false)
	end)

	t.test("cacheia resultado bem-sucedido, retém >8 compras e mantém limite padrão de 100 por jogador", function()
		local idem = RequestIdempotency.new()
		local player = { UserId = 10 }
		local executions = 0

		local res1 = idem:Execute(player, "req-1", function()
			executions += 1
			return { ok = true, data = { uuid = "pet-1" } }
		end)
		local res2 = idem:Execute(player, "req-1", function()
			executions += 1
			return { ok = true, data = { uuid = "pet-2" } }
		end)

		t.eq(executions, 1)
		t.eq(res1.ok, true)
		t.eq(res2.ok, true)
		t.eq(res2.data.uuid, "pet-1", "replay do mesmo requestId deve retornar resultado cacheado")

		-- Mais de 8 compras novas (ex.: 20 compras) NÃO podem expulsar req-1
		for i = 2, 21 do
			local res = idem:Execute(player, `req-{i}`, function()
				executions += 1
				return { ok = true, data = { index = i } }
			end)
			t.eq(res.ok, true)
		end
		t.eq(executions, 21)
		t.ok(idem:GetCompleted(player, "req-1") ~= nil, "req-1 deve permanecer retido após 20 compras novas")
		local replayAfter20 = idem:Execute(player, "req-1", function()
			executions += 1
			return { ok = true, data = { uuid = "pet-dup" } }
		end)
		t.eq(executions, 21, "replay após 20 compras deve devolver cache sem reexecutar")
		t.eq(replayAfter20.data.uuid, "pet-1")

		-- Preenche até o cap de 100: req-1 .. req-100 devem permanecer retidos
		for i = 22, 100 do
			local res = idem:Execute(player, `req-{i}`, function()
				executions += 1
				return { ok = true, data = { index = i } }
			end)
			t.eq(res.ok, true)
		end
		t.eq(executions, 100)
		t.ok(idem:GetCompleted(player, "req-1") ~= nil, "req-1 deve permanecer retido até a 100ª entrada")
		t.ok(idem:GetCompleted(player, "req-100") ~= nil)

		-- 101ª entrada expulsa somente a mais antiga (req-1), mantendo req-2 .. req-101
		local res101 = idem:Execute(player, "req-101", function()
			executions += 1
			return { ok = true, data = { index = 101 } }
		end)
		t.eq(res101.ok, true)
		t.eq(executions, 101)
		t.eq(idem:GetCompleted(player, "req-1"), nil, "entrada mais antiga além do limite de 100 deve ser removida")
		t.ok(idem:GetCompleted(player, "req-2") ~= nil)
		t.ok(idem:GetCompleted(player, "req-101") ~= nil)
	end)

	t.test("erro lógico ou exceção libera inFlight garantidamente e não cacheia falha", function()
		local idem = RequestIdempotency.new(8)
		local player = { UserId = 20 }
		local attempts = 0

		local errRes = idem:Execute(player, "req-fail", function()
			attempts += 1
			return { ok = false, err = "NOT_ENOUGH_COINS" }
		end)
		t.eq(errRes.ok, false)
		t.eq(errRes.err, "NOT_ENOUGH_COINS")
		t.eq(idem:IsInFlight(player, "req-fail"), false)
		t.eq(idem:GetCompleted(player, "req-fail"), nil, "erro não deve ser cacheado em completed")

		local boomRes = idem:Execute(player, "req-boom", function()
			attempts += 1
			error("falha simulada no Update")
		end)
		t.eq(boomRes.ok, false)
		t.eq(boomRes.err, "INTERNAL")
		t.eq(idem:IsInFlight(player, "req-boom"), false, "exceção deve liberar slot inFlight via pcall")

		local retryAfterBoom = idem:Execute(player, "req-boom", function()
			attempts += 1
			return { ok = true, data = { recovered = true } }
		end)
		t.eq(retryAfterBoom.ok, true)
		t.eq(retryAfterBoom.data.recovered, true)
		t.eq(attempts, 3)
	end)

	t.test("Remove limpa estado do jogador no PlayerRemoving", function()
		local idem = RequestIdempotency.new(8)
		local player = { UserId = 30 }

		local res = idem:Execute(player, "req-a", function()
			return { ok = true, data = { ok = 1 } }
		end)
		t.eq(res.ok, true)
		t.ok(idem:GetCompleted(player, "req-a") ~= nil)

		idem:Remove(player)
		t.eq(idem:GetCompleted(player, "req-a"), nil)
		t.eq(idem:IsInFlight(player, "req-a"), false)
	end)
end
