--!nocheck
-- RequestGuard.spec.luau (testes Lune de Shared.Logic.RequestGuard)
-- Dono: Squad B. Prova trava < 8s, timeout recuperável que libera UI preservando requestId,
-- retry idempotente pós-8s, resposta tardia, liquidação única e cancelamento de timer.

local RequestGuard = require("../src/shared/Logic/RequestGuard")
local RequestIdempotency = require("../src/shared/Logic/RequestIdempotency")

local function createFakeScheduler()
	local timers = {}
	local cancelled = {}
	local nextId = 0

	local function schedule(seconds: number, callback: () -> ())
		nextId += 1
		local handle = {
			id = nextId,
			seconds = seconds,
			callback = callback,
			cancelled = false,
			fired = false,
		}
		timers[nextId] = handle
		return handle
	end

	local function cancel(handle)
		if handle and not handle.cancelled then
			handle.cancelled = true
			table.insert(cancelled, handle.id)
		end
	end

	local function fire(handle)
		if handle and not handle.cancelled and not handle.fired then
			handle.fired = true
			handle.callback()
		end
	end

	return {
		schedule = schedule,
		cancel = cancel,
		fire = fire,
		timers = timers,
		cancelled = cancelled,
	}
end

return function(t)
	t.test("a) bloqueio < 8s: tentativa simultânea enquanto busy é bloqueada", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)

		t.eq(guard:IsBusy(), false)
		t.eq(guard:GetActiveToken(), nil)
		t.eq(guard:GetActiveRequestId(), nil)

		local token1, reqId1 = guard:Begin("CandyEgg")
		t.ok(token1 ~= nil and type(reqId1) == "string" and #reqId1 > 0, "primeira requisição deve iniciar")
		t.eq(guard:IsBusy(), true)
		t.eq(guard:GetActiveToken(), token1)
		t.eq(guard:GetActiveRequestId(), reqId1)
		t.eq(guard:HasPending("CandyEgg"), true)

		local token2, reqId2 = guard:Begin("CandyEgg")
		t.eq(token2, nil, "segunda requisição simultânea deve ser bloqueada antes dos 8s")
		t.eq(reqId2, nil)
		t.eq(guard:IsBusy(), true)
		t.eq(guard:GetActiveToken(), token1)
		t.eq(guard:GetActiveRequestId(), reqId1)
	end)

	t.test("b) timeout de 8s libera UI (sem deadlock eterno) mas mantém requestId pendente", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)
		local timeoutCount = 0

		local token1, reqId1 = guard:Begin("CandyEgg")
		t.ok(token1 ~= nil and reqId1 ~= nil)

		local timerHandle = guard:ScheduleTimeout(token1 :: number, 8, scheduler.schedule, function()
			timeoutCount += 1
		end)
		t.ok(timerHandle ~= nil)
		t.eq(timerHandle.seconds, 8)

		-- Dispara o timer de 8s enquanto InvokeServer nunca retornou
		scheduler.fire(timerHandle)

		t.eq(timeoutCount, 1, "callback de aviso deve rodar uma única vez no timeout")
		t.eq(guard:HasTimedOut(), true)
		t.eq(guard:IsBusy(), false, "UI deve ser liberada após 8s (zero deadlock eterno)")
		t.eq(guard:GetActiveToken(), nil)
		t.eq(guard:GetActiveRequestId(), nil)
		t.eq(guard:HasPending("CandyEgg"), true, "requestId pendente deve permanecer associado à chave")
		t.eq(guard:GetPendingRequestId("CandyEgg"), reqId1)
		t.eq(#scheduler.cancelled, 0, "timer já disparado não deve chamar cancel")

		-- Disparo redundante do mesmo token não deve repetir aviso
		t.eq(guard:OnTimeout(token1 :: number), false)
		t.eq(timeoutCount, 1)
	end)

	t.test("c) retry pós-8s reusa mesmo requestId e servidor retorna cache / bloqueia duplicação", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)
		local idempotency = RequestIdempotency.new(8)
		local player = { UserId = 42, Name = "Alice" }
		local coins = 500
		local hatchedPets = 0

		local function serverPurchaseEgg(requestId: string)
			return idempotency:Execute(player, requestId, function()
				coins -= 100
				hatchedPets += 1
				return {
					ok = true,
					data = { uuid = `pet-{hatchedPets}`, petId = "CottonCat" },
				}
			end)
		end

		-- Tentativa 1 (t = 0s)
		local token1, reqId1 = guard:Begin("CandyEgg")
		t.ok(token1 ~= nil and reqId1 ~= nil)
		local timer1 = guard:ScheduleTimeout(token1 :: number, 8, scheduler.schedule, function() end)

		-- Servidor processou a tentativa 1, mas resposta demorou (> 8s)
		local firstServerRes = serverPurchaseEgg(reqId1 :: string)
		t.eq(firstServerRes.ok, true)
		t.eq(coins, 400)
		t.eq(hatchedPets, 1)

		-- Timeout de 8s dispara no cliente antes da resposta chegar
		scheduler.fire(timer1)
		t.eq(guard:IsBusy(), false)
		t.eq(guard:GetPendingRequestId("CandyEgg"), reqId1)

		-- Jogador clica novamente após os 8s -> reusa exatamente o mesmo requestId com novo token
		local token2, reqId2 = guard:Begin("CandyEgg")
		t.ok(token2 ~= nil and token2 ~= token1)
		t.eq(reqId2, reqId1, "retry pós-8s deve reutilizar o mesmo requestId pendente")
		t.eq(guard:IsBusy(), true)

		local retryServerRes = serverPurchaseEgg(reqId2 :: string)
		t.eq(retryServerRes.ok, true)
		t.eq(retryServerRes.data.uuid, firstServerRes.data.uuid, "servidor deve devolver resultado cacheado")
		t.eq(coins, 400, "zero cobrança duplicada no retry")
		t.eq(hatchedPets, 1, "zero pet duplicado no retry")

		local accepted, _ = guard:ResolveDefinitive(token2 :: number, reqId2 :: string)
		t.eq(accepted, true)
		t.eq(guard:IsBusy(), false)
		t.eq(guard:HasPending("CandyEgg"), false)
		t.eq(guard:IsSettled(reqId1 :: string), true)
	end)

	t.test("d) resposta tardia sem retry ainda conclui, liquida requestId e gera novo ID depois", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)

		local token1, reqId1 = guard:Begin("rebirth")
		t.ok(token1 ~= nil and reqId1 ~= nil)

		local timer1 = guard:ScheduleTimeout(token1 :: number, 8, scheduler.schedule, function() end)
		scheduler.fire(timer1)
		t.eq(guard:IsBusy(), false)
		t.eq(guard:GetPendingRequestId("rebirth"), reqId1)

		-- Resposta tardia chega sem que o jogador tenha clicado de novo
		local accepted, wasTimedOut = guard:ResolveDefinitive(token1 :: number, reqId1 :: string)
		t.eq(accepted, true, "resposta tardia deve ser aceita e processada normalmente")
		t.eq(wasTimedOut, true)
		t.eq(guard:IsBusy(), false)
		t.eq(guard:HasPending("rebirth"), false)
		t.eq(guard:IsSettled(reqId1 :: string), true)

		-- Próxima ação intencional gera um novo requestId
		local token2, reqId2 = guard:Begin("rebirth")
		t.ok(token2 ~= nil and token2 ~= token1)
		t.ok(reqId2 ~= nil and reqId2 ~= reqId1, "após liquidação, nova ação deve gerar novo requestId")
	end)

	t.test("e) resposta tardia + retry liquidam no máximo 1 vez no cliente e cancelam timer pendente", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)
		local processedCount = 0
		local retryTimeoutCount = 0

		local token1, reqId1 = guard:Begin("CandyEgg")
		local timer1 = guard:ScheduleTimeout(token1 :: number, 8, scheduler.schedule, function() end)
		scheduler.fire(timer1)

		-- Retry após 8s abre tentativa 2 com timer2
		local token2, reqId2 = guard:Begin("CandyEgg")
		t.eq(reqId2, reqId1)
		local timer2 = guard:ScheduleTimeout(token2 :: number, 8, scheduler.schedule, function()
			retryTimeoutCount += 1
		end)

		-- Tentativa 1 (tardia) chega primeiro com ok = true enquanto tentativa 2 estava em voo
		if guard:ResolveDefinitive(token1 :: number, reqId1 :: string) then
			processedCount += 1
		end
		t.eq(processedCount, 1)
		t.eq(guard:IsBusy(), false, "liquidação pela tentativa 1 deve liberar a UI da tentativa 2")
		t.eq(timer2.cancelled, true, "timer da tentativa 2 deve ser cancelado quando o mesmo requestId liquida")

		-- Tentativa 2 chega depois com ok = true (cacheado pelo servidor) -> ignorada
		if guard:ResolveDefinitive(token2 :: number, reqId2 :: string) then
			processedCount += 1
		end
		t.eq(processedCount, 1, "não deve processar/exibir hatch duas vezes")

		-- Timer residual da tentativa 2 não dispara falso erro
		timer2.callback()
		t.eq(retryTimeoutCount, 0)
	end)

	t.test("f) resposta no prazo cancela timer sem falso toast e gera novo requestId na próxima compra", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)
		local timeoutCount = 0

		local token1, reqId1 = guard:Begin("CandyEgg")
		t.ok(token1 ~= nil and reqId1 ~= nil)

		local timer1 = guard:ScheduleTimeout(token1 :: number, 8, scheduler.schedule, function()
			timeoutCount += 1
		end)
		t.ok(timer1 ~= nil)

		local accepted, wasTimedOut = guard:ResolveDefinitive(token1 :: number, reqId1 :: string)
		t.eq(accepted, true)
		t.eq(wasTimedOut, false)
		t.eq(guard:IsBusy(), false)
		t.eq(guard:HasPending("CandyEgg"), false)
		t.eq(#scheduler.cancelled, 1, "deve cancelar timer imediatamente na resposta")
		t.eq(timer1.cancelled, true)

		timer1.callback()
		t.eq(timeoutCount, 0, "não deve disparar falso timeout após resposta no prazo")

		local token2, reqId2 = guard:Begin("CandyEgg")
		t.ok(token2 ~= nil and reqId2 ~= nil and reqId2 ~= reqId1, "próxima compra deve usar novo requestId")
	end)

	t.test("erro transitório RATE_LIMITED libera UI mantendo requestId pendente para retry", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)

		local token1, reqId1 = guard:Begin("CandyEgg")
		local timer1 = guard:ScheduleTimeout(token1 :: number, 8, scheduler.schedule, function() end)
		scheduler.fire(timer1)

		local token2, reqId2 = guard:Begin("CandyEgg")
		t.eq(reqId2, reqId1)
		local timer2 = guard:ScheduleTimeout(token2 :: number, 8, scheduler.schedule, function() end)

		-- Servidor responde RATE_LIMITED porque tentativa 1 ainda está em voo no servidor
		local handled = guard:ResolveTransient(token2 :: number, reqId2 :: string)
		t.eq(handled, true)
		t.eq(timer2.cancelled, true)
		t.eq(guard:IsBusy(), false)
		t.eq(guard:HasPending("CandyEgg"), true)
		t.eq(guard:GetPendingRequestId("CandyEgg"), reqId1)
		t.eq(guard:IsSettled(reqId1 :: string), false)

		-- Novo retry ainda usa o mesmo requestId e pode concluir normalmente
		local token3, reqId3 = guard:Begin("CandyEgg")
		t.eq(reqId3, reqId1)
		local accepted, _ = guard:ResolveDefinitive(token3 :: number, reqId3 :: string)
		t.eq(accepted, true)
		t.eq(guard:HasPending("CandyEgg"), false)
	end)

	t.test("chaves distintas mantêm pendências independentes e Reset invalida gerações antigas", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)

		local tCandy, idCandy = guard:Begin("CandyEgg")
		local timerCandy = guard:ScheduleTimeout(tCandy :: number, 8, scheduler.schedule, function() end)
		scheduler.fire(timerCandy)

		-- Muda para outro ovo enquanto CandyEgg está pendente
		local tChoco, idChoco = guard:Begin("ChocolateEgg")
		t.ok(idChoco ~= idCandy)
		local timerChoco = guard:ScheduleTimeout(tChoco :: number, 8, scheduler.schedule, function() end)

		-- Resposta tardia de CandyEgg liquida CandyEgg sem destravar ChocolateEgg que está ativo
		local candyAccepted, _ = guard:ResolveDefinitive(tCandy :: number, idCandy :: string)
		t.eq(candyAccepted, true)
		t.eq(guard:HasPending("CandyEgg"), false)
		t.eq(guard:IsBusy(), true)
		t.eq(guard:GetActiveRequestId(), idChoco)
		t.eq(timerChoco.cancelled, false)

		-- Reset cancela timer ativo e invalida respostas anteriores
		guard:Reset()
		t.eq(guard:IsBusy(), false)
		t.eq(guard:HasPending("ChocolateEgg"), false)
		t.eq(timerChoco.cancelled, true)

		local chocoAccepted, _ = guard:ResolveDefinitive(tChoco :: number, idChoco :: string)
		t.eq(chocoAccepted, false, "resposta anterior ao Reset deve ser ignorada")
	end)

	t.test("SettlePending liquida pendência pós-timeout ou em voo e impede dupla liquidação tardia", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)

		-- Pós-timeout: limpa pendência e marca requestId como liquidado
		local t1, id1 = guard:Begin("rebirth")
		local timer1 = guard:ScheduleTimeout(t1 :: number, 8, scheduler.schedule, function() end)
		scheduler.fire(timer1)
		t.eq(guard:HasPending("rebirth"), true)
		t.eq(guard:IsBusy(), false)

		local settledId = guard:SettlePending("rebirth")
		t.eq(settledId, id1)
		t.eq(guard:HasPending("rebirth"), false)
		t.eq(guard:IsSettled(id1 :: string), true)
		local lateAccepted, _ = guard:ResolveDefinitive(t1 :: number, id1 :: string)
		t.eq(lateAccepted, false, "resposta tardia após SettlePending não deve reprocessar")

		-- Em voo: cancela timer ativo, libera UI e liquida requestId
		local t2, id2 = guard:Begin("rebirth")
		local timer2 = guard:ScheduleTimeout(t2 :: number, 8, scheduler.schedule, function() end)
		t.eq(guard:IsBusy(), true)
		local settledInFlight = guard:SettlePending("rebirth")
		t.eq(settledInFlight, id2)
		t.eq(guard:IsBusy(), false)
		t.eq(guard:HasPending("rebirth"), false)
		t.eq(timer2.cancelled, true)
	end)
end
