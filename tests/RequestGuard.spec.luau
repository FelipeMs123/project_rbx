--!nocheck
-- RequestGuard.spec.luau (testes Lune de Shared.Logic.RequestGuard)
-- Dono: Squad B. Prova trava em voo, timeout não destrutivo, resposta tardia e cancelamento de timer.

local RequestGuard = require("../src/shared/Logic/RequestGuard")

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
	t.test("a) tentativa simultânea enquanto inFlight é bloqueada", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)

		t.eq(guard:IsInFlight(), false)
		t.eq(guard:GetActiveToken(), nil)

		local token1 = guard:Begin()
		t.ok(token1 ~= nil, "primeira requisição deve iniciar e devolver token")
		t.eq(guard:IsInFlight(), true)
		t.eq(guard:GetActiveToken(), token1)

		local token2 = guard:Begin()
		t.eq(token2, nil, "segunda requisição simultânea deve ser bloqueada enquanto em voo")
		t.eq(guard:IsInFlight(), true)
		t.eq(guard:GetActiveToken(), token1)
	end)

	t.test("b) timeout enquanto inFlight NÃO libera nova chamada nem descarta a resposta pendente", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)
		local timeoutCount = 0

		local token = guard:Begin()
		t.ok(token ~= nil)

		local timerHandle = guard:ScheduleTimeout(token :: number, 8, scheduler.schedule, function()
			timeoutCount += 1
		end)
		t.ok(timerHandle ~= nil)
		t.eq(timerHandle.seconds, 8)

		-- Dispara o timer de 8s enquanto o servidor ainda não respondeu
		scheduler.fire(timerHandle)

		t.eq(timeoutCount, 1, "callback de aviso deve rodar uma única vez no timeout")
		t.eq(guard:HasTimedOut(), true)
		t.eq(guard:IsInFlight(), true, "lock em voo deve permanecer ativo após timeout")
		t.eq(guard:GetActiveToken(), token, "token pendente não pode ser descartado no timeout")
		t.eq(#scheduler.cancelled, 0, "timer já disparado não deve chamar cancel")

		-- Tentativa de nova compra/rebirth após o timeout continua bloqueada
		t.eq(guard:Begin(), nil, "não deve liberar chamada duplicada após timeout enquanto em voo")
		-- Disparo redundante do timeout não deve repetir aviso
		t.eq(guard:OnTimeout(token :: number), false)
		t.eq(timeoutCount, 1)
	end)

	t.test("c) resposta tardia pós-timeout resolve corretamente e só então libera para nova ação", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)
		local timeoutCount = 0

		local token1 = guard:Begin()
		t.ok(token1 ~= nil)

		local timerHandle = guard:ScheduleTimeout(token1 :: number, 8, scheduler.schedule, function()
			timeoutCount += 1
		end)

		scheduler.fire(timerHandle)
		t.eq(timeoutCount, 1)
		t.eq(guard:IsInFlight(), true)
		t.eq(guard:Begin(), nil)

		-- Resposta tardia do servidor chega após os 8s
		local accepted, wasTimedOut = guard:Resolve(token1 :: number)
		t.eq(accepted, true, "resposta tardia do mesmo token deve ser aceita")
		t.eq(wasTimedOut, true, "deve sinalizar que houve timeout antes da resolução")
		t.eq(guard:IsInFlight(), false, "lock só libera após a resposta retornar")
		t.eq(guard:HasTimedOut(), false)
		t.eq(guard:GetActiveToken(), nil)

		-- Resposta duplicada para o mesmo token não deve ser aceita novamente
		local dupAccepted, _ = guard:Resolve(token1 :: number)
		t.eq(dupAccepted, false)

		-- Agora uma nova ação é permitida com novo token
		local token2 = guard:Begin()
		t.ok(token2 ~= nil and token2 ~= token1, "deve liberar nova requisição após resolução tardia")
		t.eq(guard:IsInFlight(), true)
	end)

	t.test("d) resposta antes do timeout cancela e ignora callback do timeout sem falso erro", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)
		local timeoutCount = 0

		local token = guard:Begin()
		t.ok(token ~= nil)

		local timerHandle = guard:ScheduleTimeout(token :: number, 8, scheduler.schedule, function()
			timeoutCount += 1
		end)
		t.ok(timerHandle ~= nil)

		-- Resposta chega antes do timeout
		local accepted, wasTimedOut = guard:Resolve(token :: number)
		t.eq(accepted, true)
		t.eq(wasTimedOut, false)
		t.eq(guard:IsInFlight(), false)
		t.eq(#scheduler.cancelled, 1, "deve cancelar o timer imediatamente na resposta")
		t.eq(scheduler.cancelled[1], timerHandle.id)
		t.eq(timerHandle.cancelled, true)

		-- Mesmo se o callback antigo fosse invocado manualmente depois (race residual), deve ser ignorado
		timerHandle.callback()
		t.eq(timeoutCount, 0, "não deve disparar falso erro de timeout após a resposta")
	end)

	t.test("Reset cancela timer ativo e invalida resposta tardia de geração anterior", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)
		local timeoutCount = 0

		local oldToken = guard:Begin()
		t.ok(oldToken ~= nil)

		local oldTimer = guard:ScheduleTimeout(oldToken :: number, 8, scheduler.schedule, function()
			timeoutCount += 1
		end)

		guard:Reset()
		t.eq(guard:IsInFlight(), false)
		t.eq(guard:HasTimedOut(), false)
		t.eq(guard:GetActiveToken(), nil)
		t.eq(oldTimer.cancelled, true)

		-- Resposta da geração destruída não deve afetar uma nova geração iniciada depois
		local newToken = guard:Begin()
		t.ok(newToken ~= nil and newToken ~= oldToken)

		local oldAccepted, _ = guard:Resolve(oldToken :: number)
		t.eq(oldAccepted, false, "resposta da geração antiga deve ser ignorada após Reset")
		t.eq(guard:IsInFlight(), true, "nova requisição não pode ser destravada pela antiga")
		t.eq(guard:GetActiveToken(), newToken)

		oldTimer.callback()
		t.eq(timeoutCount, 0)
	end)

	t.test("valida entradas inválidas e execução síncrona de scheduler", function()
		local scheduler = createFakeScheduler()
		local guard = RequestGuard.new(scheduler.cancel)

		-- Fora de voo não agenda timer
		t.eq(guard:ScheduleTimeout(1, 8, scheduler.schedule, function() end), nil)

		local token = guard:Begin()
		t.ok(token ~= nil)

		-- Token errado ou segundos inválidos não agendam timer
		t.eq(guard:ScheduleTimeout((token :: number) + 99, 8, scheduler.schedule, function() end), nil)
		t.eq(guard:ScheduleTimeout(token :: number, -1, scheduler.schedule, function() end), nil)
		t.eq(guard:ScheduleTimeout(token :: number, 0 / 0, scheduler.schedule, function() end), nil)

		-- Scheduler síncrono dispara callback imediatamente sem chamar cancel depois
		local syncFired = 0
		guard:ScheduleTimeout(token :: number, 0, function(_secs, cb)
			cb()
			return { id = 999 }
		end, function()
			syncFired += 1
		end)
		t.eq(syncFired, 1)
		t.eq(guard:HasTimedOut(), true)
		t.eq(guard:IsInFlight(), true)
		t.eq(#scheduler.cancelled, 0)

		local accepted, wasTimedOut = guard:Resolve(token :: number)
		t.eq(accepted, true)
		t.eq(wasTimedOut, true)
		t.eq(#scheduler.cancelled, 0)
	end)
end
